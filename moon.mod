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

name = "STW135-2026/moonsentinel"

version = "0.1.0"

readme = "README.md"

repository = "https://github.com/STW135-2026/moonsentinel"

license = "Apache-2.0"

keywords = [ "arrow", "data-quality", "privacy", "validation", "wasm" ]

preferred_target = "js"

description = "Arrow-native data quality and privacy release gate for MoonBit"

import {
  "shunge/arrow@0.1.0",
}
