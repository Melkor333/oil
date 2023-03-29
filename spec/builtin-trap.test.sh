# builtin-trap.test.sh

#### trap -l
trap -l | grep INT >/dev/null
## status: 0
## N-I dash/mksh status: 1

#### trap accepts/ignores --
trap -- 'echo hi' EXIT
echo done
## STDOUT:
done
hi
## END

#### trap 'echo hi' KILL (regression test, caught by smoosh suite)
trap 'echo hi' 9
echo status=$?
trap 'echo hi' KILL
echo status=$?
trap 'echo hi' STOP
echo status=$?
trap 'echo hi' TERM
echo status=$?
## STDOUT:
status=0
status=0
status=0
status=0
## END
## OK osh STDOUT:
status=1
status=1
status=1
status=0
## END

#### trap -p
case $SH in (dash|mksh) exit ;; esac

trap 'echo exit' EXIT
# debug trap also remains on
#trap 'echo debug' DEBUG

trap -p > parent.txt

trap -p | cat > child.txt

grep EXIT parent.txt >/dev/null
echo status=$?

grep EXIT child.txt >/dev/null
echo status=$?

#grep DEBUG parent.txt >/dev/null
#echo status=$?

#grep DEBUG child.txt >/dev/null
#echo status=$?

## STDOUT:
status=0
status=0
exit
## END
## N-I dash/mksh STDOUT:
## END

#### Register invalid trap
trap 'foo' SIGINVALID
## status: 1

#### Remove invalid trap
trap - SIGINVALID
## status: 1

#### SIGINT and INT are aliases
trap - SIGINT
echo $?
trap - INT
echo $?
## STDOUT:
0
0
## END
## N-I dash STDOUT:
1
0
## END

#### Invalid trap invocation
trap 'foo'
echo status=$?
## stdout: status=2
## OK dash stdout: status=1
## BUG mksh stdout: status=0

#### exit 1 when trap code string is invalid
# All shells spew warnings to stderr, but don't actually exit!  Bad!
trap 'echo <' EXIT
echo status=$?
## stdout: status=1
## BUG mksh status: 1
## BUG mksh stdout: status=0
## BUG dash/bash status: 0
## BUG dash/bash stdout: status=0

#### trap EXIT calling exit
cleanup() {
  echo "cleanup [$@]"
  exit 42
}
trap 'cleanup x y z' EXIT
## stdout: cleanup [x y z]
## status: 42

#### trap EXIT return status ignored
cleanup() {
  echo "cleanup [$@]"
  return 42
}
trap 'cleanup x y z' EXIT
## stdout: cleanup [x y z]
## status: 0

#### trap EXIT with PARSE error
trap 'echo FAILED' EXIT
for
## stdout: FAILED
## status: 2
## OK mksh status: 1

#### trap EXIT with PARSE error and explicit exit
trap 'echo FAILED; exit 0' EXIT
for
## stdout: FAILED
## status: 0

#### trap EXIT with explicit exit
trap 'echo IN TRAP; echo $stdout' EXIT 
stdout=FOO
exit 42

## status: 42
## STDOUT:
IN TRAP
FOO
## END

#### trap with command sub / subshell / pipeline
trap 'echo EXIT TRAP' EXIT 

echo $(echo command sub)

( echo subshell )

echo pipeline | cat

## STDOUT:
command sub
subshell
pipeline
EXIT TRAP
## END

#### trap DEBUG
case $SH in (dash|mksh) exit ;; esac

debuglog() {
  echo "  [$@]"
}
trap 'debuglog $LINENO' DEBUG

echo a
echo b; echo c

echo d && echo e
echo f || echo g

(( h = 42 ))
[[ j == j ]]

## STDOUT:
  [8]
a
  [9]
b
  [9]
c
  [11]
d
  [11]
e
  [12]
f
  [14]
  [15]
## END
## N-I dash/mksh STDOUT:
## END

#### trap DEBUG and command sub / subshell
case $SH in (dash|mksh) exit ;; esac

debuglog() {
  echo "  [$@]"
}
trap 'debuglog $LINENO' DEBUG

echo "result =" $(echo command sub)
( echo subshell )
echo done

## STDOUT:
  [8]
result = command sub
subshell
  [10]
done
## END
## N-I dash/mksh STDOUT:
## END

#### trap DEBUG and pipeline
case $SH in (dash|mksh) exit 1 ;; esac

debuglog() {
  echo "  [$@]"
}
trap 'debuglog $LINENO' DEBUG

# gets run for each one of these
{ echo a; echo b; }

# only run for the last one, maybe I guess because traps aren't inherited?
{ echo x; echo y; } | wc -l

# gets run for both of these
date | wc -l

date |
  wc -l

## STDOUT:
  [8]
a
  [8]
b
  [10]
2
  [12]
  [12]
1
  [14]
  [15]
1
## END
## N-I dash/mksh status: 1
## N-I dash/mksh stdout-json: ""


#### trap DEBUG with compound commands
case $SH in (dash|mksh) exit 1 ;; esac

# I'm not sure if the observed behavior actually matches the bash documentation
# ...
#
# https://www.gnu.org/software/bash/manual/html_node/Bourne-Shell-Builtins.html#Bourne-Shell-Builtins
#
# "If a sigspec is DEBUG, the command arg is executed before every simple 
# command, for command, case command, select command, every arithmetic for
# command, and before the first command executes in a shell function."

debuglog() {
  echo "  [$@]"
}
trap 'debuglog $LINENO' DEBUG

f() {
  local mylocal=1
  for i in "$@"; do
    export i=$i
  done
}

echo '-- assign --'
g=1   # executes ONCE here

echo '-- function call --'
f A B C  # executes ONCE here, but does NOT go into th efunction call


echo '-- for --'
# why does it execute twice here?  because of the for loop?  That's not a
# simple command.
for i in 1 2; do
  echo for1 $i
  echo for2 $i
done

echo '-- while --'
i=0
while (( i < 2 )); do
  echo while1 
  echo while2
  (( i++ ))
done

echo '-- if --'
if true; then
  echo IF
fi

echo '-- case --'
case x in
  (x)
    echo CASE
esac

## STDOUT:
  [16]
-- assign --
  [17]
  [19]
-- function call --
  [20]
  [23]
-- for --
  [24]
  [25]
for1 1
  [26]
for2 1
  [24]
  [25]
for1 2
  [26]
for2 2
  [29]
-- while --
  [30]
  [31]
  [32]
while1
  [33]
while2
  [34]
  [31]
  [32]
while1
  [33]
while2
  [34]
  [31]
  [37]
-- if --
  [38]
  [39]
IF
  [42]
-- case --
  [43]
  [45]
CASE
## END
## N-I dash/mksh status: 1
## N-I dash/mksh stdout-json: ""


#### trap RETURN
profile() {
  echo "profile [$@]"
}
g() {
  echo --
  echo g
  echo --
  return
}
f() {
  echo --
  echo f
  echo --
  g
}
# RETURN trap doesn't fire when a function returns, only when a script returns?
# That's not what the manual syas.
trap 'profile x y' RETURN
f
. $REPO_ROOT/spec/testdata/return-helper.sh
## status: 42
## STDOUT:
--
f
--
--
g
--
return-helper.sh
profile [x y]
## END
## N-I dash/mksh STDOUT:
--
f
--
--
g
--
return-helper.sh
## END

#### trap ERR and disable it
err() {
  echo "err [$@] $?"
}
trap 'err x y' ERR 
echo 1
false
echo 2
trap - ERR  # disable trap
false
echo 3
## STDOUT:
1
err [x y] 1
2
3
## END
## N-I dash STDOUT:
1
2
3
## END

#### trap 0 is equivalent to EXIT
# not sure why this is, but POSIX wants it.
trap 'echo EXIT' 0
echo status=$?
trap - EXIT
echo status=$?
## status: 0
## STDOUT:
status=0
status=0
## END

#### trap 1 is equivalent to SIGHUP; HUP is equivalent to SIGHUP
trap 'echo HUP' SIGHUP
echo status=$?
trap 'echo HUP' HUP
echo status=$?
trap 'echo HUP' 1
echo status=$?
trap - HUP
echo status=$?
## status: 0
## STDOUT:
status=0
status=0
status=0
status=0
## END
## N-I dash STDOUT:
status=1
status=0
status=0
status=0
## END

#### eval in the exit trap (regression for issue #293)
trap 'eval "echo hi"' 0
## STDOUT:
hi
## END


#### exit codes for traps are isolated

trap 'echo USR1 trap status=$?; ( exit 42 )' USR1

echo before=$?

# Equivalent to 'kill -USR1 $$' except OSH doesn't have "kill" yet.
# /bin/kill doesn't exist on Debian unless 'procps' is installed.
sh -c "kill -USR1 $$"
echo after=$?

## STDOUT:
before=0
USR1 trap status=0
after=0
## END

#### traps are cleared in subshell (started with &)

# bash is FLAKY on CI for some reason.  dash/mksh are enough for us to test
# against.
case $SH in bash) exit ;; esac

trap 'echo USR1' USR1

kill -USR1 $$

# Hm trap doesn't happen here
{ echo begin child; sleep 0.1; echo end child; } &
kill -USR1 $!
wait

echo done

## STDOUT:
USR1
begin child
end child
done
## END
## BUG bash STDOUT:
## END
