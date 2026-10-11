"""Exercise Boost.Python against the installed target CPython runtime."""
import sys
sys.path.insert(0, sys.argv[1])
import tdvp_boost_probe as module

assert sys.version_info[:2] == (3, 13)
assert module.square(12) == 144
counter = module.Counter(40)
assert counter.add(2) == 42 and counter.value == 42
try:
    module.square(-1)
except ValueError:
    pass
else:
    raise AssertionError('C++ exception was not translated')
try:
    module.square('invalid')
except TypeError:
    pass
else:
    raise AssertionError('invalid Python argument was not rejected')
print('Boost.Python target CPython 3.13: PASS import, functions, class state, exceptions and argument validation')
