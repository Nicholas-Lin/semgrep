(*
   Entrypoint for the 'spacecat' command.
*)

open Cmdliner
open Spacegrep

type config = { is_pattern : bool; debug : bool; input_files : string list }

let is_pattern_term =
  let info =
    Arg.info [ "pattern"; "p" ]
      ~doc:"Interpret the input as a pattern rather than a document."
  in
  Arg.value (Arg.flag info)

let debug_term =
  let info =
    Arg.info [ "debug" ]
      ~doc:
        "Print the tree in a richer, unambiguous format suitable for\n\
        \            debugging."
  in
  Arg.value (Arg.flag info)

let input_files_term =
  let info =
    Arg.info [] ~docv:"FILE"
      ~doc:
        "Read documents from files or directories $(docv) instead of\n\
        \            from stdin."
  in
  Arg.value (Arg.pos_all Arg.string [] info)

let cmdline_term =
  let combine is_pattern debug input_files =
    { is_pattern; debug; input_files }
  in
  Term.(const combine $ is_pattern_term $ debug_term $ input_files_term)

let doc = "use a universal parser to interpret a program as a tree"

let man =
  [
    `S Manpage.s_description;
    `P
      "Read an arbitrary program from stdin and print the parse tree\n\
      \      to stdout.";
    `S Manpage.s_authors;
    `P "Martin Jambon <martin@returntocorp.com>";
    `S Manpage.s_bugs;
    `P
      "Check out bug reports at https://github.com/returntocorp/semgrep/issues.";
    `S Manpage.s_see_also;
    `P "spacegrep(1)";
  ]

let info name = Term.info ~doc ~man name

let parse_command_line name =
  match Term.eval (cmdline_term, info name) with
  | `Error _ -> exit 1
  | `Version | `Help -> exit 0
  | `Ok config -> config

let run_one config input =
  let src =
    match input with
    | `Stdin -> Src_file.of_stdin ()
    | `File path -> Src_file.of_file path
  in
  let pat =
    if config.is_pattern then Parse_pattern.of_src src
    else Parse_doc.of_src src |> Doc_AST.to_pattern
  in
  let print = if config.debug then Print.Debug.to_stdout else Print.to_stdout in
  print pat

let run config =
  match config.input_files with
  | [] -> run_one config `Stdin
  | roots ->
      let files = Find_files.list roots in
      List.iter (fun path -> run_one config (`File path)) files

let main () =
  let config = parse_command_line "spacecat" in
  run config
