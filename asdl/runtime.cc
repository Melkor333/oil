// asdl/runtime.cc: This file generated by mycpp from asdl/runtime.py

#include "mylib.h"
#include "hnode_asdl.h"

Str* str0 = new Str("(");
Str* str1 = new Str(")");
Str* str2 = new Str("_");
Str* str3 = new Str("T");
Str* str4 = new Str("F");

namespace runtime {  // forward declare

}  // forward declare namespace runtime

namespace runtime {  // declare
extern int NO_SPID;
hnode_asdl::hnode__Record* NewRecord(Str* node_type);
hnode_asdl::hnode__Leaf* NewLeaf(Str* s, hnode_asdl::color_t e_color);
extern Str* TRUE_STR;
extern Str* FALSE_STR;

}  // declare namespace runtime

namespace runtime {  // define
using hnode_asdl::hnode__Record;
using hnode_asdl::hnode__Leaf;
using hnode_asdl::color_t;
using hnode_asdl::color_e;
int NO_SPID = -1;

hnode_asdl::hnode__Record* NewRecord(Str* node_type) {
  return new hnode__Record(node_type, new List<hnode_asdl::field*>(), false, str0, str1, new List<hnode_asdl::hnode_t*>());
}

hnode_asdl::hnode__Leaf* NewLeaf(Str* s, hnode_asdl::color_t e_color) {
  if (s == nullptr) {
    return new hnode__Leaf(str2, color_e::OtherConst);
  }
  else {
    return new hnode__Leaf(s, e_color);
  }
}
Str* TRUE_STR = str3;
Str* FALSE_STR = str4;

}  // define namespace runtime

