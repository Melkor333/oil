"""
runtime.py
"""
from __future__ import print_function

import cStringIO
import sys

from pylib import collections_
try:
    import posix_ as posix
except ImportError:
    # Hack for tangled dependencies.
    import os
    posix = os

from typing import Tuple, Dict, Optional, Any

# For conditional translation
CPP = False
PYTHON = True

# Use POSIX name directly
STDIN_FILENO = 0


def MaybeCollect():
    # type: () -> None
    pass


def NewDict():
    """Make dictionaries ordered in Python, e.g. for JSON.
  
    In C++, our Dict implementation should be ordered.
    """
    return collections_.OrderedDict()


def print_stderr(s):
    # type: (str) -> None
    """Print a message to stderr for the user.

    This should be used sparingly, since it doesn't have location info, like
    ui.ErrorFormatter does.  We use it to print fatal I/O errors that were only
    caught at the top level.
    """
    print(s, file=sys.stderr)


BufWriter = cStringIO.StringIO

BufLineReader = cStringIO.StringIO


def Stdout():
    return sys.stdout


def Stderr():
    return sys.stderr


def Stdin():
    return sys.stdin


# mylib.open is the builtin, but we have different static types mylib.pyi
open = open


class switch(object):
    """A ContextManager that translates to a C switch statement."""

    def __init__(self, value):
        # type: (int) -> None
        self.value = value

    def __enter__(self):
        # type: () -> switch
        return self

    def __exit__(self, type, value, traceback):
        # type: (Any, Any, Any) -> bool
        return False  # Allows a traceback to occur

    def __call__(self, *cases):
        # type: (*Any) -> bool
        return self.value in cases


class tagswitch(object):
    """A ContextManager that translates to switch statement over ASDL types."""

    def __init__(self, node):
        # type: (int) -> None
        self.tag = node.tag()

    def __enter__(self):
        # type: () -> tagswitch
        return self

    def __exit__(self, type, value, traceback):
        # type: (Any, Any, Any) -> bool
        return False  # Allows a traceback to occur

    def __call__(self, *cases):
        # type: (*Any) -> bool
        return self.tag in cases


def iteritems(d):
    """Make translation a bit easier."""
    return d.iteritems()


def split_once(s, delim):
    # type: (str, str) -> Tuple[str, Optional[str]]
    """Easier to call than split(s, 1) because of tuple unpacking."""

    parts = s.split(delim, 1)
    if len(parts) == 1:
        no_str = None  # type: Optional[str]
        return s, no_str
    else:
        return parts[0], parts[1]


def hex_lower(i):
    # type: (int) -> str
    return '%x' % i


def hex_upper(i):
    # type: (int) -> str
    return '%X' % i


def octal(i):
    # type: (int) -> str
    return '%o' % i


def dict_erase(d, key):
    # type: (Dict[Any, Any], Any) -> None
    """
    Ensure that a key isn't in the Dict d.  This makes C++ translation easier.
    """
    try:
        del d[key]
    except KeyError:
        pass


def str_cmp(s1, s2):
    # type: (str, str) -> int
    if s1 == s2:
        return 0
    if s1 < s2:
        return -1
    else:
        return 1


def log(msg, *args):
    # type: (str, *Any) -> None
    """Print debug output to stderr."""
    if args:
        msg = msg % args
    print(msg, file=sys.stderr)


class UniqueObjects(object):
    """A set of objects identified by their address in memory

    Python's id(obj) returns the address of any object.  But we don't simply
    implement it, because it requires a uint64_t on 64-bit systems, while mycpp
    only supports 'int'.

    So we have a whole class.

    Should be used for:

    - Cycle detection when pretty printing, as Python's repr() does
      - See CPython's Objects/object.c PyObject_Repr()
      /* These methods are used to control infinite recursion in repr, str, print,
          etc.  Container objects that may recursively contain themselves,
          e.g. builtin dictionaries and lists, should use Py_ReprEnter() and
          Py_ReprLeave() to avoid infinite recursion.
          */
      - e.g. dictobject.c dict_repr() calls Py_ReprEnter() to print {...}
      - In Python 2.7 a GLOBAL VAR is used

      - It also checks for STACK OVERFLOW

    - Packle serialization
    """
    def __init__(self):
        # 64-bit id() -> small integer ID
        self.addresses = {}  # type: Dict[int, int]

    def Contains(self, obj):
        # type: (Any) -> bool
        """ Convenience? """
        return self.Get(obj) != -1

    def MaybeAdd(self, obj):
        # type: (Any) -> None
        """ Convenience? """

    # def AddNewObject(self, obj):
    def Add(self, obj):
        # type: (Any) -> None
        """
        Assert it isn't already there, and assign a new ID!

        # Lib/pickle does:

            self.memo[id(obj)] = memo_len, obj

        I guess that's the object ID and a void*

        Then it does:

            x = self.memo.get(id(obj))

        and

            # If the object is already in the memo, this means it is
            # recursive. In this case, throw away everything we put on the
            # stack, and fetch the object back from the memo.
            if id(obj) in self.memo:
                write(POP + self.get(self.memo[id(obj)][0]))

        BUT It only uses the numeric ID!
        """
        addr = id(obj)
        assert addr not in self.addresses
        self.addresses[addr] = len(self.addresses)

    def Get(self, obj):
        # type: (Any) -> int
        """
        Returns unique ID assigned

        Returns -1 if it doesn't exist?
        """
        addr = id(obj)
        return self.addresses.get(addr, -1)

    # Note: self.memo.clear() doesn't appear to be used


if 0:
    # Prototype of Unix file descriptor I/O, compared with FILE* libc I/O.
    # Doesn't seem like we need this now.

    # Short versions of STDOUT_FILENO and STDERR_FILENO
    kStdout = 1
    kStderr = 2

    def writeln(s, fd=kStdout):
        # type: (str) -> None
        """Write a line.  The name is consistent with JavaScript writeln() and Rust.

        e.g.
        writeln("x = %d" % x, kStderr)

        TODO: The Oil interpreter shouldn't use print() anywhere.  Instead it can use
        writeln(s) and writeln(s, kStderr)
        """
        posix.write(fd, s)
        posix.write(fd, '\n')

    class File(object):
        """Custom file wrapper for Unix I/O like write() read()
    
        Not C I/O like fwrite() fread().  There should be no flush().
        """

        def __init__(self, fd):
            # type: (int) -> None
            self.fd = fd

        def write(self, s):
            # type: (str) -> None
            posix.write(self.fd, s)

        def writeln(self, s):
            # type: (str) -> None
            writeln(s, fd=self.fd)
