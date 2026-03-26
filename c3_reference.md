# C3 Language Quick Reference

A practical reference for the C3 programming language, compiled from the c3c compiler source and standard library.

---

## 1. Language Overview

C3 is a systems programming language that builds on C syntax, aiming to evolve it while retaining familiarity for C programmers. It features module-based namespacing, generics, compile-time execution, and zero-cost error handling.

**Key Principles:**
- C ABI compatibility
- No mandatory header files
- Module-based namespacing (module name is part of the type)
- Zero-cost error handling via Result types
- Compile-time reflection and execution

---

## 2. Basic Syntax

### 2.1 Modules

```c3
module my_module;
// or with submodules
module my_module::submodule;
```

**File Organization:**
- One module per `.c3` file
- Module name derived from file path (e.g., `src/foo/bar.c3` → `foo::bar`)

### 2.2 Imports

```c3
import std::io;           // Import standard I/O
import std::collections::list;  // Import submodule
import my_module;         // Import local module

// Selective import
using std::io;  // brings io:: into current namespace
```

### 2.3 Functions

```c3
// Basic function
fn void my_function(int param)
{
    // function body
}

// Function returning a value
fn int add(int a, int b)
{
    return a + b;
}

// Method (value method - first param is &self or self)
fn void MyStruct.do_something(&self)
{
    // Can call as: my_struct.do_something();
}

// Shorthand method syntax (from stdlib)
fn void my_func(int x) @inline => x * 2;  // Single expression
```

### 2.4 Structs

```c3
struct Point
{
    int x;
    int y;
}

// With methods
struct Rect
{
    int x, y, width, height;
    
    fn int Rect.area(&self)
    {
        return self.width * self.height;
    }
}
```

### 2.5 Enums

```c3
// Simple enum
enum Color
{
    RED,
    GREEN,
    BLUE
}

// Enum with associated values (C3 feature)
enum HttpStatus : (int code, String message)
{
    OK = { 200, "OK" },
    NOT_FOUND = { 404, "Not Found" },
    // Access: HttpStatus.OK.code
}

// Const enum (like C enums)
const enum LogLevel
{
    DEBUG,
    INFO,
    ERROR
}
```

### 2.6 Aliases

```c3
// Type alias
alias IntList = List {int};

// Module alias
alias collections = std::collections;
```

---

## 3. Naming Conventions

From c3c's CODESTYLE.md:

| Element | Convention | Example |
|---------|------------|---------|
| Constants | UPPER_SNAKE_CASE | `MAX_BUFFER_SIZE` |
| Macros | UPPER_SNAKE_CASE | `MY_MACRO(123)` |
| Types (struct/enum) | PascalCase | `MyLittleType` |
| Functions | snake_case | `my_little_function(123)` |
| Variables | snake_case | `context` |
| Enum values | PascalCase or UPPER_SNAKE | `RED` or `Red` |

**Brace Style:** Allman (opening brace on new line)

```c3
fn void foo()
{
    if (condition)
    {
        // code
    }
}
```

---

## 4. Important Attributes

Attributes modify behavior of declarations:

```c3
// Common attributes
@inline          // Suggest inlining
@noinline        // Prevent inlining
@pure            // Function has no side effects
@local           // Symbol not exported
@private         // Not accessible outside module
@public          // Accessible everywhere
@deprecated      // Mark as deprecated
@export          // Export symbol
@test            // Mark as test function
@benchmark       // Mark as benchmark
@operator        // Define operator overload
@dynamic         // Dynamic function (runtime dispatch)
@if(condition)   // Conditional compilation
```

---

## 5. Compile-Time Features

### 5.1 Macros

```c3
// Macro function
macro int square(int x) => x * x;

// Macro with compile-time logic
macro bool is_power_of_2($Type)
{
    $if $Type.kindof == FLOAT:
        return false;
    $else
        return ($Type.sizeof & ($Type.sizeof - 1)) == 0;
    $endif
}
```

### 5.2 Compile-Time Variables ($)

```c3
// Compile-time variable
$define MAX_SIZE 100

// Usage in macros
macro void process(int[$MAX_SIZE] arr) { ... }
```

### 5.3 $if / $switch (Compile-Time Conditionals)

```c3
$if $typeof(x) == int:
    // compile-time branch
$else
    // other branch
$endif
```

### 5.4 $sizeof, $typeof, $nameof

```c3
usz size = $sizeof(int);      // Get size at compile time
typeid t = $typeof(my_var);   // Get type at compile time
String name = $nameof(my_var); // Get variable name
```

---

## 6. Error Handling

### 6.1 Faults (Result Types)

```c3
// Define a fault
def FileError = error || io::Error;

// Function returning Result
fn File!open_file(String path)
{
    if (some_error) return FileError.BAD_PATH?;
    return file;
}

// Using ?
fn void read_data()
{
    File f = open_file("data.txt")!;  // Unwrap or propagate
    // or
    if (try f = open_file("data.txt"))
    {
        // success
    }
}
```

### 6.2 Try/Catch

```c3
fn void handle()
{
    try
    {
        risky_operation()!;
    }
    catch (FileError e)
    {
        // Handle error
    }
}
```

---

## 7. Generics

### 7.1 Generic Modules

```c3
// Define generic module
module stack{Type};

struct Stack
{
    Type* data;
    usz capacity;
    usz size;
}

fn void Stack.push(Stack* this, Type element) { ... }
fn Type Stack.pop(Stack* this) { ... }

// Use generic
import stack;
alias IntStack = Stack {int};
alias StringStack = Stack {String};
```

### 7.2 Generic Functions

```c3
fn void swap(&x, &y)
{
    typeof(x) temp = x;
    x = y;
    y = temp;
}
```

---

## 8. Common Patterns from Stdlib

### 8.1 Initialization

```c3
// Stack-allocated with default values
MyStruct obj = {};

// Named initialization
MyStruct obj = { .x = 10, .y = 20 };

// With allocator
List* list = List.init(&mem, 16);
defer list.free();  // cleanup
```

### 8.2 Optional Values

```c3
// Optional type
int? maybe_value = get_optional();

// Check and unwrap
if (try val = maybe_value)
{
    // val is unwrapped here
}
```

### 8.3 Slices

```c3
char[] buffer = "Hello World";
char[] slice = buffer[0..5];  // "Hello"

// Slice from pointer
char[] view = ptr[0:len];
```

### 8.4 Operators

```c3
// Define operator overload
fn bool MyType.eq(&self, MyType other) @operator(==)
{
    return self.value == other.value;
}
```

---

## 9. Operators Reference

| Operator | Description |
|----------|-------------|
| `&&` | Logical AND |
| `\|\|` | Logical OR |
| `??` | Null-coalesce |
| `!` | Unwrap/assert |
| `?` | Make optional |
| `??` | Elvis operator |
| `??` | Try operator (in try context) |
| `.` | Member access |
| `::` | Module/path separator |
| `..` | Range (inclusive) |
| `[..]` | Slice |
| `[<]` | Exclusive range start |
| `[>]` | Exclusive range end |
| `=` | Assignment |
| `==` | Equality (needs overload) |

---

## 10. Key Standard Library Modules

| Module | Purpose |
|--------|---------|
| `std::io` | Input/output, printing |
| `std::collections::list` | Dynamic arrays |
| `std::collections::hashmap` | Key-value maps |
| `std::collections::hashset` | Unique element sets |
| `std::math` | Math functions |
| `std::string` | String manipulation |
| `std::time` | Time/date handling |
| `std::threads` | Threading |
| `std::net::tcp` | TCP networking |
| `std::net::udp` | UDP networking |

---

## 11. Built-in Macros ($$)

These are compiler intrinsics:

```c3
$$abs(x)              // Absolute value
$$sqrt(x)             // Square root
$$sin(x), $$cos(x)   // Trigonometry
$$popcount(x)         // Count set bits
$$clz(x)              // Count leading zeros
$$ctz(x)              // Count trailing zeros
$$byte_swap(x)        // Byte swap
$$memcpy(dst, src, n) // Memory copy
$$memset(dst, val, n) // Memory set
$$printf(...)         // Compile-time format checking
$$str_hash(x)         // String hash
```

---

## 12. Common Gotchas

1. **Module names are part of types:** `List` vs `std::collections::List` are different
2. **No header files:** All code goes in `.c3` files
3. **Optional trailing comma:** Allowed in struct initializers
4. **Slices are views:** They don't own data
5. **Methods use `&self` or `self`:** Value methods use `self`, pointer methods use `&self`
6. **Enums need `.ordinal` for numeric value:** `MyEnum.VALUE.ordinal`

---

## 13. Building & Running

```bash
# Compile single file
c3c compile main.c3

# Compile with output name
c3c compile -o myapp main.c3

# Use standard library
c3c compile --stdlib /path/to/lib/std main.c3

# Build project
c3c build

# Run tests
c3c test
```

---

## 14. Further Resources

- Official Manual: https://www.c3-lang.org
- GitHub: https://github.com/c3lang/c3c
- Discord: https://discord.gg/qN76R87
