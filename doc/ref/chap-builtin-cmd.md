---
in_progress: yes
body_css_class: width40 help-body
default_highlighter: oil-sh
---

Builtin Commands
===

This chapter in the [Oils Reference](index.html) describes builtin commands for OSH and YSH.

<div id="toc">
</div>

## Memory

### append

Append a string to an array of strings:

    var mylist = :| one two |
    append :mylist three

This is a command-mode synonym for the expression:

    _ mylist->append('three')

### pp

Pretty prints interpreter state.  Some of these are implementation details,
subject to change.

Examples:

    pp proc  # print all procs and their doc comments

    var x = :| one two |
    pp cell x  # print a cell, which is a location for a value

## Handle Errors

### try

Run a block of code, stopping at the first error (i.e. errexit is enabled).
Set the `_status` variable to the exit status of the block, and returns 0.

    try {
      ls /nonexistent

      ls | wc -l

      diff <(sort left.txt) <(sort right.txt)

      var x = 1 / 0
    }
    if (_status !== 0) {
      echo 'error'
    }

    # Shortcut for a single command
    try grep PATTERN FILE.txt
    case $_status in
      (0) echo 'found' ;;
      (1) echo 'not found' ;;
      (*) echo "error $_status" ;;
    esac

### boolstatus

Runs a command and requires the exit code to be 0 or 1.

    if boolstatus egrep '[0-9]+' myfile {  # may abort
      echo 'found'               # status 0 means found
    } else {
      echo 'not found'           # status 1 means not found
    }



## Shell State

### ysh-cd

It takes a block:

    cd / {
      echo $PWD
    }

### ysh-shopt

It takes a block:

    shopt --unset errexit {
      false
      echo 'ok'
    }

### shvar

Execute a block with a global variable set.

    shvar IFS=/ {
      echo "ifs is $IFS"
    }
    echo "ifs restored to $IFS"

### push-registers

Save global registers like $? on a stack.  It's useful for preventing plugins
from interfering with user code.  Example:

    status_42         # returns 42 and sets $?
    push-registers {  # push a new frame
      status_43       # top of stack changed here
      echo done
    }                 # stack popped
    echo $?           # 42, read from new top-of-stack

Current list of registers:

    BASH_REMATCH        aka  _match()
    $?             
    _status             set by the try builtin
    PIPESTATUS          aka  _pipeline_status
    _process_sub_status


## Modules

### runproc

Runs a named proc with the given arguments.  It's often useful as the only top
level statement in a "task file":

    proc p {
      echo hi
    }
    runproc @ARGV
    
Like 'builtin' and 'command', it affects the lookup of the first word.

### module

Registers a name in the global module dict.  Returns 0 if it doesn't exist, or
1 if it does.

Use it like this in executable files:

    module main || return 0   

And like this in libraries:

    module myfile.ysh || return 0   

### is-main

The `is-main` builtin returns 1 (false) if the current file was executed with
the `source` builtin.

In the "main" file, including `-c` or `stdin` input, it returns 0 (true).

Use it like this:

    if is-main {
      runproc @ARGV
    }

### use

Make declarations about the current file.

For files that contain embedded DSLs:

    use dialect ninja  # requires that _DIALECT is set to 'ninja'

An accepted declaration that tools can use, but isn't used by Oil:

    use bin grep sed

## I/O

### ysh-read

Oil adds buffered, line-oriented I/O to shell's `read`.

    read --line             # default var is $_line
    read --line --with-eol  # keep the \n
    read --line --qsn       # decode QSN too
    read --all              # whole file including newline; var is $_all
    read -0                 # read until NUL, synonym for read -r -d ''

When --qsn is passed, the line is check for an opening single quote.  If so,
it's decoded as QSN.  The line must have a closing single quote, and there
can't be any non-whitespace characters after it.

### write

write fixes problems with shell's `echo` builtin.

The default separator is a newline, and the default terminator is a
newline.

Examples:

    write -- ale bean        # write two lines
    write --qsn -- ale bean  # QSN encode, guarantees two lines
    write -n -- ale bean     # synonym for --end '', like echo -n
    write --sep '' --end '' -- a b        # write 2 bytes
    write --sep $'\t' --end $'\n' -- a b  # TSV line

### fork

The preferred alternative to shell's `&`.

    fork { sleep 1 }
    wait -n

### forkwait

The preferred alternative to shell's `()`.  Prefer `cd` with a block if possible.

    forkwait {
      not_mutated=zzz
    }
    echo $not_mutated



## Data Formats

### json

Write JSON:

    var d = {name: 'bob', age: 42}
    json write (d)

Read JSON into a variable:

    var x = ''
    json read :x < myfile.txt


## Testing

TODO: describe

## External Lang

TODO: when


## I/O

These builtins take input and output.  They're often used with redirects.

### read

    read FLAG* VAR*

Read a line from stdin, split it into tokens with the `$IFS` algorithm,
and assign the tokens to the given variables.  When no VARs are given,
assign to `$REPLY`.

Note: When writing Oil, prefer the extensions documented in
[oil-read]($oil-help).  The `read` builtin is confusing because `-r` needs to
be explicitly enabled.

Flags:

    -a ARRAY  assign the tokens to elements of this array
    -d CHAR   use DELIM as delimiter, instead of newline
    -n NUM    read up to NUM characters, respecting delimiters
    -p STR    print the string PROMPT before reading input
    -r        raw mode: don't let backslashes escape characters
    -s        silent: do not echo input coming from a terminal
    -t NUM    time out and fail after TIME seconds
              -t 0 returns whether any input is available
    -u FD     read from file descriptor FD instead of 0 (stdin)

  <!--  -N NUM    read up to NUM characters, ignoring delimiters -->
  <!--  -e        use readline to obtain the line
        -i STR    use STR as the initial text for readline -->

### echo

    echo FLAG* ARG*

Prints ARGs to stdout, separated by a space, and terminated by a newline.

Flags:

    -e  enable interpretation of backslash escapes
    -n  omit the trailing newline
<!--  -E  -->

See [char-escapes]($osh-help).

### printf

    printf FLAG* FMT ARG*

Formats values and prints them.  The FMT string contain three types of objects:

1. Literal Characters
2. Character escapes like `\t`.  See [char-escapes]($osh-help).
3. Percent codes like `%s` that specify how to format each each ARG.

If not enough ARGS are passed, the empty string is used.  If too many are
passed, the FMT string will be "recycled".

Flags:

    -v VAR  Write output in variable VAR instead of standard output.

Format specifiers:

    %%  Prints a single "%".
    %b  Interprets backslash escapes while printing.
    %q  Prints the argument escaping the characters needed to make it reusable
        as shell input.
    %d  Print as signed decimal number.
    %i  Same as %d.
    %o  Print as unsigned octal number.
    %u  Print as unsigned decimal number.
    %x  Print as unsigned hexadecimal number with lower-case hex-digits (a-f).
    %X  Same as %x, but with upper-case hex-digits (A-F).
    %f  Print as floating point number.
    %e  Print as a double number, in "±e" format (lower-case e).
    %E  Same as %e, but with an upper-case E.
    %g  Interprets the argument as double, but prints it like %f or %e.
    %G  Same as %g, but print it like %E.
    %c  Print as a single char, only the first character is printed.
    %s  Print as string
    %n  The number of characters printed so far is stored in the variable named
        in the argument.
    %a  Interprets the argument as double, and prints it like a C99 hexadecimal
        floating-point literal.
    %A  Same as %a, but print it like %E.
    %(FORMAT)T  Prints date and time, according to FORMAT as a format string
                for strftime(3). The argument is the number of seconds since
                epoch. It can also be -1 (current time, also the default value
                if there is no argument) or -2 (shell startup time).

### readarray

Alias for `mapfile`.

#### mapfile

    mapfile FLAG* ARRAY?

Reads lines from stdin into the variable named ARRAY (default
`${MAPFILE[@]}`).

Flags:

    -t       Remove the trailing newline from every line
<!--
  -d CHAR  use CHAR as delimiter, instead of the default newline
  -n NUM   copy up to NUM lines
  -O NUM   begins copying lines at the NUM element of the array
  -s NUM   discard the first NUM lines
  -u FD    read from FD file descriptor instead of the standard input
  -C CMD   run CMD every NUM lines specified in -c
  -c NUM   every NUM lines, the CMD command in C will be run
-->

## Run Code

These builtins accept shell code and run it.

### source

    source SCRIPT ARG*

Executes SCRIPT with given ARGs in the context of the current shell.  It will
modify existing variables.

### eval

    eval ARG+

Creates a string by joining ARGs with a space, then runs it as a shell command.

Example:

     # Create the string echo "hello $name" and run it.
     a='echo'
     b='"hello $name"'
     eval $a $b

Tips:

`eval` is usually unnecessary in Oil code.  Using it can confuse code and
user-supplied data, leading to [security issues][].

Prefer passing single string ARG to `eval`.

[security issues]: https://mywiki.wooledge.org/BashFAQ/048

### trap

    trap FLAG* CMD SIGNAL*

Registers the shell string CMD to be run after the SIGNALs are received.  If
the CMD is empty, then the signal is ignored.

Flags:

    -l  Lists all signals and their signal number
    -p  Prints a list of the installed signal handlers

Tip:

Prefer passing the name of a shell function to `trap`.

## Set Options

The `set` and `shopt` builtins set global shell options.  Oil code should use
the more natural `shopt`.

### set

    set FLAG* ARG*

Sets global shell options. Short style:

    set -e

Long style:

    set -o errexit

Set the arguments array:

    set -- 1 2 3

### shopt

    shopt FLAG* OPTION* BLOCK?

Sets global shell options.

Flags:

    -s --set    Turn the named options on
    -u --unset  Turn the named options off
    -p          Print option values
    -q          Return 0 if the option is true, else 1

Examples: 

    shopt --set errexit

You can set or unset multiple options with the groups `strict:all`,
`ysh:upgrade`, and `ysh:all`.

If a block is passed, then the mutated options are pushed onto a stack, the
block is executed, and then options are restored to their original state.

## Working Dir

These 5 builtins deal with the working directory of the shell.

### cd

    cd FLAG* DIR

Changes the working directory of the current shell process to DIR.

If DIR isn't specified, change to `$HOME`.  If DIR is `-`, change to `$OLDPWD`
(a variable that the sets to the previous working directory.)

Flags:

    -L  Follow symbolic links, i.e. change to the TARGET of the symlink.
        (default).
    -P  Don't follow symbolic links.

### pwd

    pwd FLAG*

Prints the current working directory.

Flags:

    -L  Follow symbolic links if present (default)
    -P  Don't follow symbolic links.  Print the link instead of the target.

### pushd

<!--pushd FLAGS DIR-->
    pushd DIR
<!--pushd +/-NUM-->

Add DIR to the directory stack, then change the working directory to DIR.
Typically used with `popd` and `dirs`.

<!--FLAGS:
  -n  Don't change the working directory, just manipulate the stack 
NUM:
  Rotates the stack the number of places specified. Eg, given the stack
  '/foo /bar /baz', where '/foo' is the top of the stack, pushd +1 will move
  it to the bottom, '/bar /baz /foo'-->

### popd

    popd

Removes a directory from the directory stack, and changes the working directory
to it.  Typically used with `pushd` and `dirs`.

### dirs

    dirs FLAG*

Shows the contents of the directory stack.  Typically used with `pushd` and
`popd`.

Flags:

    -c  Clear the dir stack.
    -l  Show the dir stack, but with the real path instead of ~.
    -p  Show the dir stack, but formatted as one line per entry.
    -v  Like -p, but numbering each line.

## Completion

These builtins implement Oil's bash-compatible autocompletion system.

### complete

Registers completion policies for different commands.

### compgen

Generates completion candidates inside a user-defined completion function.

It can also be used in scripts, i.e. outside a completion function.

### compopt

Changes completion options inside a user-defined completion function.

### compadjust

Adjusts `COMP_ARGV` according to specified delimiters, and optionally set
variables cur, prev, words (an array), and cword.  May also set 'split'.

This is an OSH extension that makes it easier to run the bash-completion
project.

### compexport

Complete an entire shell command string.  For example,

    compexport -c 'echo $H'

will complete variables like `$HOME`.  And

    compexport -c 'ha'

will complete builtins like `hay`, as well as external commands.


## Shell Process

These builtins mutate the state of the shell process.

### exec

    exec BIN_PATH ARG*

Replaces the running shell with the binary specified, which is passed ARGs.
BIN_PATH must exist on the file system; i.e. it can't be a shell builtin or
function.

### umask

    umask MODE?

Sets the bit mask that determines the permissions for new files and
directories.  The mask is subtracted from 666 for files and 777 for
directories.

Oil currently supports writing masks in octal.

If no MODE, show the current mask.

### times

    times

Shows the user and system time used by the shell and its child processes.

## Child Process

### jobs

    jobs

Shows all jobs running in the shell and their status.

### wait

    wait FLAG* ARG

Wait for processes to exit.

If the ARG is a PID, wait only for that job, and return its status.

If there's no ARG, wait for all child processes.

<!--
The ARG can be a PID (tracked by the kernel), or a job number (tracked by the
shell).  Specify jobs with the syntax `%jobnumber`.
-->

Flags:

    -n  Wait for the next process to exit, rather than a specific process.

Wait can be interrupted by a signal, in which case the exit code indicates the
signal number.

### fg

    fg JOB?

Returns a job running in the background to the foreground.  If no JOB is
specified, use the latest job.

<!--<h4 id="bg">bg</h4>

The bg builtin resumes suspend job, while keeping it in the background.

bg JOB?

JOB:
  Job ID to be resumed in the background. If none is specified, the latest job
  is chosen. -->

## External

### test

    test OP ARG
    test ARG OP ARG
    [ OP ARG ]      # [ is an alias for test that requires closing ]
    [ ARG OP ARG ]

Evaluates a conditional expression and returns 0 (true) or 1 (false).

Note that [ is the name of a builtin, not an operator in the language.  Use
'test' to avoid this confusion.

String expressions:

    -n STR           True if STR is not empty.
                     'test STR' is usually equivalent, but discouraged.
    -z STR           True if STR is empty.
    STR1 = STR2      True if the strings are equal.
    STR1 != STR2     True if the strings are not equal.
    STR1 < STR2      True if STR1 sorts before STR2 lexicographically.
    STR1 > STR2      True if STR1 sorts after STR2 lexicographically.
                     Note: < and > should be quoted like \< and \>

File expressions:

    -a FILE          Synonym for -e.
    -b FILE          True if FILE is a block special file.
    -c FILE          True if FILE is a character special file.
    -d FILE          True if FILE is a directory.
    -e FILE          True if FILE exists.
    -f FILE          True if FILE is a regular file.
    -g FILE          True if FILE has the sgid bit set.
    -G FILE          True if current user's group is also FILE's group.
    -h FILE          True if FILE is a symbolic link.
    -L FILE          True if FILE is a symbolic link.
    -k FILE          True if FILE has the sticky bit set.
    -O FILE          True if current user is the file owner.
    -p FILE          True if FILE is a named pipe (FIFO).
    -r FILE          True if FILE is readable.
    -s FILE          True if FILE has size bigger than 0.
    -S FILE          True if FILE is a socket file.
    -t FD            True if file descriptor FD is open and refers to a terminal.
    -u FILE          True if FILE has suid bit set.
    -w FILE          True if FILE is writable.
    -x FILE          True if FILE is executable.
    FILE1 -nt FILE2  True if FILE1 is newer than FILE2 (mtime).
    FILE1 -ot FILE2  True if FILE1 is older than FILE2 (mtime).
    FILE1 -ef FILE2  True if FILE1 is a hard link to FILE2.
<!--    -N FILE  True if FILE was modified since last read (mtime newer than atime).-->

Arithmetic expressions coerce arguments to integers, then compare:

    INT1 -eq INT2    True if they're equal.
    INT1 -ne INT2    True if they're not equal.
    INT1 -lt INT2    True if INT1 is less than INT2.
    INT1 -le INT2    True if INT1 is less or equal than INT2.
    INT1 -gt INT2    True if INT1 is greater than INT2.
    INT1 -ge INT2    True if INT1 is greater or equal than INT2.

Other expressions:

    -o OPTION        True if the shell option OPTION is set.
    -v VAR           True if the variable VAR is set.

The test builtin also supports POSIX conditionals like -a, -o, !, and ( ), but
these are discouraged.

<!--    -R VAR     True if the variable VAR has been set and is a nameref variable. -->

Oil supports these long flags:

    --dir            same as -d
    --exists         same as -e
    --file           same as -f
    --symlink        same as -L

### getopts

    getopts SPEC VAR ARG*

A single iteration of flag parsing.  The SPEC is a sequence of flag characters,
with a trailing `:` to indicate that the flag takes an argument:

    ab    # accept  -a and -b
    xy:z  # accept -x, -y arg, and -z

The input is `"$@"` by default, unless ARGs are passed.

On each iteration, the flag character is stored in VAR.  If the flag has an
argument, it's stored in `$OPTARG`.  When an error occurs, VAR is set to `?`
and `$OPTARG` is unset.

Returns 0 if a flag is parsed, or 1 on end of input or another error.

Example:

    while getopts "ab:" flag; do
        case $flag in
            a)   flag_a=1 ;;
            b)   flag_b=$OPTARG" ;;
            '?') echo 'Invalid Syntax'; break ;;
        esac
    done

Notes:
- `$OPTIND` is initialized to 1 every time a shell starts, and is used to
  maintain state between invocations of `getopts`.
- The characters `:` and `?` can't be flags.

### kill

Unimplemented.

<!-- Note: 'kill' accepts job control syntax -->

## Introspection

<h3 id="help" class="osh-topic ysh-topic" oils-embed="1">
  help
</h3>

<!-- pre-formatted for help builtin -->

```
Usage: help TOPIC?

Examples:

    help               # this help
    help echo          # help on the 'echo' builtin
    help com-sub       # help on command sub $(date)

    help oils-usage    # identical to oils-for-unix --help
    help osh-usage     #              osh --help
    help ysh-usage     #              ysh --help
```

### hash

    hash

Display information about remembered commands.

    hash FLAG* CMD+

Determine the locations of commands using `$PATH`, and remember them.

Flag:

    -r       Discard all remembered locations.
<!--    -d       Discard the remembered location of each NAME.
    -l       Display output in a format reusable as input.
    -p PATH  Inhibit path search, PATH is used as location for NAME.
    -t       Print the full path of one or more NAME.-->

### type

    type FLAG* NAME*

Print the type of each NAME.  Is it a keyword, shell builtin, shell function,
alias, or executable file?

Flags:

    -f  Don't look for functions
    -P  Only look for executable files in $PATH
    -t  Print a single word: alias, builtin, file, function, or keyword
<!--    -a  Print all executables that can run CMD, including files, aliases,
        builtins and functions. If used with -p, only the executable file will
        be printed.-->

 
## Word Lookup

### command

    command FLAG* CMD ARG*

Look up CMD as a shell builtin or executable file, and execute it with the
given ARGs.  That is, the lookup ignores shell functions named CMD.

Flags:

    -v  Instead of executing CMD, print a description of it.
        Similar to the 'type' builtin.
<!--    -p  Use a default value for PATH that is guaranteed to find all of the
        standard utilities.
    -V  Print a more verbose description of CMD.-->

### builtin

    builtin CMD ARG*

Look up CMD as a shell builtin, and execute it with the given ARGs.  That is,
the lookup ignores shell functions and executables named CMD.

## Interactive

### alias

    alias NAME=CODE

Make NAME a shortcut for executing CODE, e.g. `alias hi='echo hello'`.

    alias NAME

Show the value of this alias.

    alias

Show a list of all aliases.

Tips:

Prefer shell functions like:

    ls() {
      command ls --color "$@"
    }

to aliases like:

    alias ls='ls --color'
    
Functions are less likely to cause parsing problems.

- Quoting like `\ls` or `'ls'` disables alias expansion
- To remove an existing alias, use [unalias]($osh-help).

### unalias

    unalias NAME

Remove the alias NAME.

<!--Flag:

    -a  Removes all existing aliases.-->

### history

    history FLAG*

Display and manipulate the shell's history entries.

    history NUM

Show the last NUM history entries.

Flags:

    -c      Clears the history.
    -d POS  Deletes the history entry at position POS.
<!--    -a
    -n
    -r
    -w
    -p
    -s -->


## Unsupported

### enable

Bash has this, but OSH won't implement it.

