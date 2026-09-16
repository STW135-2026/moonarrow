// Learn more about moon.mod configuration:
// https://docs.moonbitlang.com/en/latest/toolchain/moon/module.html
//
// To add a dependency, run this command in your terminal:
//   moon add moonbitlang/x
//
// Or manually declare it in `import`, for example:
// import {
//   "moonbitlang/x@0.4.6",
// }

name = "STW135-2026/moonarrow"

version = "0.1.0"

readme = "README.md"

repository = "https://github.com/STW135-2026/moonarrow"

license = "Apache-2.0"

keywords = [ "arrow", "columnar", "dataframe", "analytics" ]

preferred_target = "js"

description = "Apache Arrow IPC reader and columnar compute primitives for MoonBit"

import {
  "moonbitlang/async@0.21.3",
}
