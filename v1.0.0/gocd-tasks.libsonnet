local escape_comments(input) = if !std.isEmpty(input) && input[0] == '#' then
  '#' + input
else
  input;

{
  noop:: {
    exec: {
      command: true,
    },
  },

  // GoCD scripts cannot contain comments with a single '#' character, they
  // new to be "escaped" by adding a second '#' character.
  script(input):: {
    script: std.join('\n', std.map(escape_comments, std.split(input, '\n'))),
  },
}
