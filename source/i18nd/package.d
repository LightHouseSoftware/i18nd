module i18nd;

protected
{
    import std.sumtype;
    import std.json;
    import std.string;
    import std.algorithm;
    import std.regex;
    import std.conv;
    import std.format;
    import std.typecons;
    import std.math;
    import std.array;
}

alias i18n = I18nService.instance;
alias Value = SumType!(int, long, double, string);

class I18nService {
    private {
        __gshared I18nService _instance;
        JSONValue _localization;
    }

    protected this() {
    }

    static I18nService instance() {
        if (!_instance) {
            synchronized (I18nService.classinfo) {
                if (!_instance)
                    _instance = new I18nService;
            }
        }

        return _instance;
    }

    void set(JSONValue json)
    {
        _localization = json;
    }

    string t(string key, Value[string] replacements = null)
    {
        return t(_localization, key, replacements);
    }

    private string t(JSONValue localization, string key, Value[string] replacements = null)
    {
        auto keys = splitter(key, '.');
        JSONValue currentValue = localization;

        foreach (k; keys)
        {
            if (currentValue.type == JSONType.object && k in currentValue.object)
            {
                currentValue = currentValue.object[k];
            }
            else
            {
                return "";
            }
        }

        string result;

        if (currentValue.type == JSONType.array)
        {
            // Processing an array of values
            string[] arrayValues;
            foreach (val; currentValue.array)
            {
                arrayValues ~= val.str; // Add a string representation of each array element
            }
            result = arrayValues.join(", ").strip; // Join array elements separated by commas
        }
        else
        {
            result = currentValue.str; // For non-array values we just use the string
        }

        // Processing regular placeholders
        if (replacements !is null)
        {
            foreach (placeholder, v; replacements)
            {
                if (result.canFind("{{" ~ placeholder ~ ".format"))
                {
                    auto formatRegex = regex(`\{\{` ~ placeholder ~ `.format\(([^)]*)\)\}\}`);
                    foreach (m; match(result, formatRegex))
                    {
                        result = result.replace(m[0], formatValue(v, Nullable!string(m[1])));
                    }
                }
                else 
                {
                    result = result.replace("{{" ~ placeholder ~ "}}", formatValue(v, Nullable!string.init));
                }
            }

        }

        // Handling pluralization
        auto pluralRegex = regex(`\{\{([^}]+)\.plural\(([^)]*)\)\}\}`);
        foreach (m; match(result, pluralRegex))
        {
            string countKey = m[1];
            if (countKey in replacements)
            {
                auto countValue = replacements[countKey];
                auto forms = splitter(m[2], ",").map!(s => s.strip).array;
                string pluralForm = processPluralization(countValue, forms);
                result = result.replace(m[0], pluralForm);
            }
        }

        // Handling references to other values
        auto re = regex(`\$t\(([^)]+)\)`);
        foreach (m; match(result, re))
        {
            string refKey = m[1];
            string refValue = t(localization, refKey, replacements);
            result = result.replace(m[0], refValue);
        }

        return result;
    }

    private string processPluralization(Value value, string[] forms)
    {
        double count = value.match!(
            (int i) => cast(double) i,
            (long l) => cast(double)l,
            (double d) => d,
            (string s) => to!double(s)
        );

        return selectPluralForm(count, forms);
    }

    private string selectPluralForm(double count, string[] forms)
    {
        auto processedForms = forms.map!(form => form == "_" ? "" : form).array;

        switch (processedForms.length)
        {
        case 3: // For Slavic languages, including Russian
            if(count != trunc(count))
            {
                return processedForms[2];
            }

            double lastDigit = count % 10.0;
            double lastTwoDigits = count % 100.0;

            if (lastDigit == 1 && lastTwoDigits != 11)
            {
                return processedForms[0]; // 1 item
            }
            else if (lastDigit >= 2 && lastDigit <= 4 && !(lastTwoDigits >= 12 && lastTwoDigits <= 14))
            {
                return processedForms[1]; // 2-4 items
            }
            else
            {
                return processedForms[2]; // 5 and more items
            }
        case 4: // For languages with four forms (such as Arabic)
            if (count == 1)
            {
                return processedForms[0];
            }
            else if (count == 2)
            {
                return processedForms[1];
            }
            else if (count > 2 && count <= 10)
            {
                return processedForms[2];
            }
            else
            {
                return processedForms[3];
            }
        default: // For languages with two forms (for example, English)
            return count == 1 ? processedForms[0] : processedForms[1];
        }
    }

    private string formatValue(Value value, Nullable!string formatter)
    {
        return value.match!(
            (int i) => !formatter.isNull ? format(formatter.get, i) : to!string(i),
            (long l) => !formatter.isNull ? format(formatter.get, l) : to!string(l),
            (double d) => !formatter.isNull ? format(formatter.get, d) : to!string(d),
            (string s) => !formatter.isNull ? format(formatter.get, s) : s
        );
    }
}

unittest
{
    // Test data
    auto json = parseJSON(`{
        "simpleKey": "Simple text",
        "nested": {
            "key": "Nested text"
        },
        "keyWithReference": "Reference: $t(nested.key)",
        "keyWithReplacements": "Name: {{name}}",
        "keyWithPlural": "{{count}} apple{{count.plural(_, s)}}",
        "formattedKey": "Number: {{number.format(%.2f)}}",
        "arrayKey": ["value1", "value2", "value{{number}}"],
        "arrayKey2": ["{{number.format(%.2f)}}", "{{number.plural(яблоко, яблока,яблок)}}", "test2"]
    }`);
    i18n.set(json);

    // Simple key test
    assert(i18n.t("simpleKey") == "Simple text");

    // Nested key test
    assert(i18n.t("nested.key") == "Nested text");

    // Test reference to another value
    assert(i18n.t("keyWithReference") == "Reference: Nested text");

    // Replacement test
    assert(i18n.t("keyWithReplacements", ["name": Value("Alice")]) == "Name: Alice");

    // Pluralization test
    assert(i18n.t("keyWithPlural", ["count": Value(1)]) == "1 apple");
    assert(i18n.t("keyWithPlural", ["count": Value(2)]) == "2 apples");
    assert(i18n.t("keyWithPlural", ["count": Value(5)]) == "5 apples");

    // Testing the formatter
    assert(i18n.t("formattedKey", ["number": Value(3.14159)]) == "Number: 3.14");

    // Testing an Array of Values
    assert(i18n.t("arrayKey", ["number": Value(3)]) == "value1, value2, value3");
    assert(i18n.t("arrayKey2", ["number": Value(3.12384)]) == "3.12, яблок, test2");

    // Non-existent key test
    assert(i18n.t("nonExistentKey") == "");
}