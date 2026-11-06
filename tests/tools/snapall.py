import sys
from lupa.lua51 import LuaRuntime
def snap(script, sc):
    lua=LuaRuntime(unpack_returned_tuples=True)
    lua.execute('package.path="./tests/?.lua;"..package.path')
    return lua.eval('dofile("tests/%s")' % script)(sc)
script=sys.argv[1]
for sc in sys.argv[2:]:
    open('/tmp/snap_%s.txt'%sc,'w').write(snap(script, sc)+'\n')
