# i18nd **— internalization library**

The i18nd library is an internationalization (i18n) tool specifically designed for the D programming language. This library provides a suite of standard i18n functionalities to facilitate the development of globally accessible applications.

Key features of i18nd include:

* **Interpolation**: Allows dynamic insertion of values into strings, making it easier to adapt text for different languages and regions without changing the program logic.
* **Formatting**: Supports various data formats, including dates, numbers, and currencies, simplifying that these elements conform to the locale-specific conventions.
* **Pluralization**: Handles the complex rules of plural forms in different languages, enabling representation of quantity-related text.
* **Nested Values**: Supports nesting of translation strings, allowing for more organized and readable code, especially in the context of complex language constructs.
* **Arrays**: Efficiently manages arrays within translation strings, ensuring correct presentation of grouped data.
* **References to Other Values**: Facilitates the reuse of translation strings, enhancing consistency and reducing redundancy in the localization process.

Data for internationalization in the i18nd library is stored in **JSON** format, providing a familiar and flexible structure for managing translation strings and locale-specific data. This choice of format enhances the library's usability and integration with various data sources and systems.

## Usage

First you need to connect the library to your project and add its import:

```D
import i18nd;
```

### Setting up Localization Data

First, load your JSON localization data using the `set` method:

```D
import std.json;

auto json = parseJSON(`{
    "simpleKey": "Simple text",
    "nested": {
        "key": "Nested text"
    },
    "keyWithReference": "Reference: $t(nested.key)",
    "keyWithReplacements": "Name: {{name}}",
    "keyWithPlural": "{{count}} apple{{count.plural(_, s)}}",
    "formattedKey": "Number: {{number.format(%.2f)}}",
    "arrayKey": ["value1", "value2", "value{{number}}"]
}`);
i18n.set(json);
```

### Basic Translation

Use the `t` method to translate a key:

```D
string translated = i18n.t("simpleKey");
writeln(translated); // Outputs: Simple text
```

### Interpolation

To replace placeholders with dynamic values:

```D
string nameTranslation = i18n.t("keyWithReplacements", ["name": Value("Alice")]);
writeln(nameTranslation); // Outputs: Name: Alice
```

### Pluralization

Handle different plural forms based on count:

```D
string oneApple = i18n.t("keyWithPlural", ["count": Value(1)]);
string twoApples = i18n.t("keyWithPlural", ["count": Value(2)]);
writeln(oneApple); // Outputs: 1 apple
writeln(twoApples); // Outputs: 2 apples
```

The word form is selected based on the number of plural elements in the array and follows the following logic: [one, many] or [one, more, many], or [one, more, many, other]. If you need to use an empty insert (as in the example), use an underscore "_".

*We are not sure if this is correct for all languages, if you know the best algorithm, then correct us.*

### Formatting

Format numbers, dates, etc., using the `.format` specifier:

```D
string formattedNumber = i18n.t("formattedKey", ["number": Value(3.14159)]);
writeln(formattedNumber); // Outputs: Number: 3.14
```

Theoretically supports any formatting [std.format](https://dlang.org/phobos/std_format.html).

### Nested Values

Access nested keys in the JSON structure:

```D
string nestedText = i18n.t("nested.key");
writeln(nestedText); // Outputs: Nested text
```

### Arrays

Work with arrays in localization data:

```D
string arrayValues = i18n.t("arrayKey", ["number": Value(3)]);
writeln(arrayValues); // Outputs: value1, value2, value3
```

### References to Other Values

Utilize references to other localization values within a translation:

```D
string refTranslation = i18n.t("keyWithReference");
writeln(refTranslation); // Outputs: Reference: Nested text
```

## Contribution

Contributions to the i18nd library are welcome. Please ensure that your changes pass all existing unittests and add new tests for new features.
