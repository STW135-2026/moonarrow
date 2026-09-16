///|
/// Arrow-style filtering: a null predicate is treated as false.
pub fn filter_int32(
  input : @array.Int32Array,
  predicate : @array.BoolArray,
) -> Result[@array.Int32Array, @array.ArrayError] {
  if predicate.len() != input.len() {
    return Err(@array.LengthMismatch(predicate.len(), input.len()))
  }
  let output : Array[Int?] = []
  for i in 0..<input.len() {
    if predicate.get(i).unwrap() == Some(true) {
      output.push(input.get(i).unwrap())
    }
  }
  Ok(@array.Int32Array::from_options(output))
}

///|
pub fn filter_int64(
  input : @array.Int64Array,
  predicate : @array.BoolArray,
) -> Result[@array.Int64Array, @array.ArrayError] {
  if predicate.len() != input.len() {
    return Err(@array.LengthMismatch(predicate.len(), input.len()))
  }
  let output : Array[Int64?] = []
  for i in 0..<input.len() {
    if predicate.get(i).unwrap() == Some(true) {
      output.push(input.get(i).unwrap())
    }
  }
  Ok(@array.Int64Array::from_options(output))
}

///|
pub fn filter_float64(
  input : @array.Float64Array,
  predicate : @array.BoolArray,
) -> Result[@array.Float64Array, @array.ArrayError] {
  if predicate.len() != input.len() {
    return Err(@array.LengthMismatch(predicate.len(), input.len()))
  }
  let output : Array[Double?] = []
  for i in 0..<input.len() {
    if predicate.get(i).unwrap() == Some(true) {
      output.push(input.get(i).unwrap())
    }
  }
  Ok(@array.Float64Array::from_options(output))
}

///|
pub fn filter_bool(
  input : @array.BoolArray,
  predicate : @array.BoolArray,
) -> Result[@array.BoolArray, @array.ArrayError] {
  if predicate.len() != input.len() {
    return Err(@array.LengthMismatch(predicate.len(), input.len()))
  }
  let output : Array[Bool?] = []
  for i in 0..<input.len() {
    if predicate.get(i).unwrap() == Some(true) {
      output.push(input.get(i).unwrap())
    }
  }
  Ok(@array.BoolArray::from_options(output))
}

///|
pub fn filter_utf8(
  input : @array.Utf8Array,
  predicate : @array.BoolArray,
) -> Result[@array.Utf8Array, @array.ArrayError] {
  if predicate.len() != input.len() {
    return Err(@array.LengthMismatch(predicate.len(), input.len()))
  }
  let output : Array[String?] = []
  for i in 0..<input.len() {
    if predicate.get(i).unwrap() == Some(true) {
      output.push(input.get(i).unwrap())
    }
  }
  Ok(@array.Utf8Array::from_options(output))
}

///|
pub fn filter_binary(
  input : @array.BinaryArray,
  predicate : @array.BoolArray,
) -> Result[@array.BinaryArray, @array.ArrayError] {
  if predicate.len() != input.len() {
    return Err(@array.LengthMismatch(predicate.len(), input.len()))
  }
  let output : Array[Bytes?] = []
  for i in 0..<input.len() {
    if predicate.get(i).unwrap() == Some(true) {
      output.push(input.get(i).unwrap())
    }
  }
  Ok(@array.BinaryArray::from_options(output))
}

///|
pub fn sum_int32(input : @array.Int32Array) -> Int64? {
  let mut total = 0L
  let mut count = 0
  for value in input.to_options() {
    match value {
      Some(value) => {
        total = total + value.to_int64()
        count = count + 1
      }
      None => ()
    }
  }
  if count == 0 {
    None
  } else {
    Some(total)
  }
}

///|
pub fn mean_int32(input : @array.Int32Array) -> Double? {
  match sum_int32(input) {
    None => None
    Some(sum) => {
      let valid_count = input.len() - input.null_count()
      Some(sum.to_double() / valid_count.to_double())
    }
  }
}

///|
pub fn min_max_int32(input : @array.Int32Array) -> (Int, Int)? {
  let mut result : (Int, Int)? = None
  for value in input.to_options() {
    match value {
      None => ()
      Some(value) =>
        match result {
          None => result = Some((value, value))
          Some((minimum, maximum)) => {
            let next_min = if value < minimum { value } else { minimum }
            let next_max = if value > maximum { value } else { maximum }
            result = Some((next_min, next_max))
          }
        }
    }
  }
  result
}

///|
pub fn greater_than_int32(
  input : @array.Int32Array,
  threshold : Int,
) -> @array.BoolArray {
  @array.BoolArray::from_options(
    input.to_options().map(value => value.map(v => v > threshold)),
  )
}

///|
pub fn greater_than_int64(
  input : @array.Int64Array,
  threshold : Int64,
) -> @array.BoolArray {
  @array.BoolArray::from_options(
    input.to_options().map(value => value.map(v => v > threshold)),
  )
}

///|
pub fn take_int32(
  input : @array.Int32Array,
  indices : Array[Int],
) -> Result[@array.Int32Array, @array.ArrayError] {
  let output : Array[Int?] = []
  for index in indices {
    match input.get(index) {
      Ok(value) => output.push(value)
      Err(error) => return Err(error)
    }
  }
  Ok(@array.Int32Array::from_options(output))
}
