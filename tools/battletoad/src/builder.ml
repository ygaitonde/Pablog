open Printf
open Unix

open Core
open Jg_template
open Jg_types

open Post
open Model

(** TODOs:
 * Caching
 * Parallelization. *)

(** Generates the blog's RSS feed *)
let generate_rss_feeds blog_model =
    blog_model


let format_date {tm_wday; tm_mon; tm_mday; tm_year; _} = 
  let day_of_week = match tm_wday with
    | 0 -> "Sunday"
    | 1 -> "Monday"
    | 2 -> "Tuesday"
    | 3 -> "Wednesday"
    | 4 -> "Thursday"
    | 5 -> "Friday"
    | _ -> "Saturday" in
  let month = match tm_mon with
    | 0 -> "January"
    | 1 -> "February"
    | 2 -> "March"
    | 3 -> "April"
    | 4 -> "May"
    | 5 -> "June"
    | 6 -> "July"
    | 7 -> "August"
    | 8 -> "September"
    | 9 -> "October"
    | 10 -> "November"
    | _ -> "December" in
  Printf.sprintf "%s, %s %d, %d" day_of_week month tm_mday (tm_year + 1900)


let format_date_index {tm_mon; tm_mday; tm_year; _} =
  Printf.sprintf "%d-%02d-%02d" (tm_year + 1900) (tm_mon + 1) tm_mday


let tag_path tag =
  match tag with
  | "archives" -> "/archives.html"
  | _ -> String.concat ["/tags/"; tag; ".html"]


let post_uri ({hostname;_}:blog_model) fs_path =
  hostname ^ "/" ^ fs_path


let or_string x default = match x with
  | Some y -> Jg_types.Tstr y
  | None -> Jg_types.Tstr default


(** Generates the blog's index and tag pages *)
let generate_index_pages blog_model =
  let () = Printf.printf "Building index pages...\n\n" in
  let split_into_tag_groups posts =
    [("archives", posts)]
  in
  let post_model {title; datetime; og_description;
                  reading_time; fs_path; _} =
    Jg_types.Tobj [
      ("title", Jg_types.Tstr title);
      ("url", Jg_types.Tstr (post_uri blog_model fs_path));
      ("datestring", Jg_types.Tstr (format_date_index datetime));
      ("description", or_string og_description "");
      ("reading_time", Jg_types.Tint reading_time);
    ]
  in
  let make_model tag posts =
    [("index_title", Jg_types.Tstr ("Posts: " ^ tag));
     ("author", Jg_types.Tstr blog_model.author);
     ("og_image", Jg_types.Tstr "https://morepablo.com/pabloface.png");
     ("full_uri", Jg_types.Tstr (blog_model.hostname ^ (tag_path tag)));
     ("posts", Jg_types.Tlist (List.map ~f:post_model posts));
    ]
  in
  let index_page tag posts =
    let models = make_model tag posts in
    Jg_template.from_file ~models:models (Filename.concat blog_model.input_fs_path "index-template.tmpl")
  in
  let () =
    blog_model.posts
    |> split_into_tag_groups
    |> List.map ~f:(fun (tag, posts) -> (tag_path tag, index_page tag posts))
    |> List.iter ~f:(Files.write_out_to_file blog_model.build_dir)
  in
  blog_model


(** Generates the blog's individual post pages *)
let generate_post_pages (blog_model:blog_model) =
  let () = Printf.printf "Building post pages...\n\n" in
  let today_now = Unix.time () |> Unix.gmtime in
  let is_old x = (today_now.tm_year - x.tm_year) > 1 in
  let tag_url tag = Jg_types.Tobj [
        ("name", Jg_types.Tstr tag);
        ("url", Jg_types.Tstr (tag_path tag))] in

  let prev_next_url = function
    | None -> Jg_types.Tnull
    | Some (linkable:post_linkable) -> Jg_types.Tobj [
        ("name", Jg_types.Tstr linkable.title);
        ("url", Jg_types.Tstr ("/" ^ linkable.path))] in

  let make_model {title; datetime; tags; og_image;
                  og_description; content; reading_time;
                  next_post_fs_path;
                  prev_post_fs_path;
                  fs_path } =
    [("title",                Jg_types.Tstr title);
     ("author",               Jg_types.Tstr blog_model.author);
     ("keywords_list",        Jg_types.Tstr "Pablo Meier engineering management tech");
     ("description_abridged", or_string og_description blog_model.description);
     ("og_description",       or_string og_description blog_model.description);
     ("og_image",             or_string og_image "https://morepablo.com/pabloface.png");
     ("full_uri",             Jg_types.Tstr (post_uri blog_model fs_path));
     ("rss_feed_uri",         Jg_types.Tstr "/feeds.xml");
     ("formatted_date",       Jg_types.Tstr (format_date datetime));
     ("tags",                 Jg_types.Tlist (List.map ~f:tag_url tags));
     ("reading_time",         Jg_types.Tint reading_time);
     ("if_old",               Jg_types.Tbool (is_old datetime));
     ("content",              Post.all_content content |> Omd.to_html |> Jg_types.Tstr);
     ("link_to_newer",        prev_next_url prev_post_fs_path);
     ("link_to_older",        prev_next_url next_post_fs_path);
    ]
  in
  let post_page p =
    let models = make_model p in
    Jg_template.from_file ~models:models (Filename.concat blog_model.input_fs_path "post_template.tmpl")
  in
  let () =
    blog_model.posts
    |> List.map ~f:(fun x -> (x.fs_path, post_page x))
    |> List.iter ~f:(Files.write_out_to_file blog_model.build_dir)
  in
  blog_model


(** Generates the blog's toplevel homepage *)
let generate_homepage blog_model =
    blog_model


(** Generates the blog's toplevel homepage *)
let generate_statics blog_model =
    blog_model


let build (model:blog_model) =
  let () = Unix.mkdir_p model.build_dir in
  model
    |> generate_index_pages
    |> generate_rss_feeds
    |> generate_post_pages
    |> generate_homepage
    |> generate_statics
