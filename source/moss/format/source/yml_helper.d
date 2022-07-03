/*
 * SPDX-FileCopyrightText: Copyright © 2020-2022 Serpent OS Developers
 *
 * SPDX-License-Identifier: Zlib
 */

/**
 * moss.format.source.yml_helper
 *
 * Helper functions for applying and enforcing schemas when parsing
 * YAML format files.
 *
 * Authors: Copyright © 2020-2022 Serpent OS Developers
 * License: Zlib
 */

module moss.format.source.yml_helper;

import dyaml;
import moss.format.source.schema;
import std.exception : enforce;
import std.experimental.logger;
import std.stdint;
import std.string : format;

/**
 * Set value appropriately.
 */
void setValue(T)(ref Node node, ref T value, YamlSchema schema)
{
    import std.algorithm : canFind;

    enforce(node.nodeID == NodeID.scalar, format!"Expected %s for %s"(T.stringof, node.tag));

    trace(format!"Function %s parsing node: '%s' with value: '%s' via schema: '%s'"(__FUNCTION__,
            node, value, schema));

    static if (is(T == int64_t))
    {
        value = node.as!int64_t;
    }
    else static if (is(T == uint64_t))
    {
        value = node.as!uint64_t;
    }
    else static if (is(T == bool))
    {
        value = node.as!bool;
    }
    else
    {
        value = node.as!string;
        if (schema.acceptableValues.length < 1)
        {
            trace(format!"'- schema '%s' has acceptableValues.length < 1"(schema));
            return;
        }

        /* Make sure the string is an acceptable value */
        enforce(schema.acceptableValues.canFind(value),
                format!"setValue(): %s not a valid value for %s. Acceptable values: %s"(value,
                    schema.name, schema.acceptableValues));
    }
    trace(format!"'- value '%s' parsed as type '%s'"(value, T.stringof));
}

/**
 * Set value according to maps.
 */
void setValueArray(T)(ref Node node, ref T value)
{

    /* We can support a single value *or* a list. */
    enforce(node.nodeID != NodeID.mapping, format!"Expected %s for %s"(T.stringof, node.tag));

    trace(format!"Function %s parsing node: '%s' with value: '%s'"(__FUNCTION__, node, value));

    switch (node.nodeID)
    {
        static if (is(T == string) || is(T == string[]))
        {
    case NodeID.scalar:
            trace(format!"  '- parsing '%s' as string scalar"(node));
            value ~= node.as!string;
            break;
    case NodeID.sequence:
            trace("  '- parsing sequence as string scalars:");
            foreach (ref Node v; node)
            {
                trace(format!"    '- parsing '%s' as string scalar"(node));
                value ~= v.as!string;
            }
            break;
        }
        else
        {
    case NodeID.scalar:
            auto v = node.as!(typeof(value[0]));
            trace(format!"  '- parsing '%s' as '%s'"(node, node.as!(typeof(value[0]))));
            value ~= node.as!(typeof(value[0]));
            break;
    case NodeID.sequence:
            trace(format!"  '- parsing sequence:"(node));
            foreach (ref Node v; node)
            {
                trace(format!"  '- parsing '%s' as '%s'"(node, node.as!(typeof(value[0]))));
                value ~= v.as(typeof(value[0]));
            }
            break;
        }
    default:
        trace("  '- parsing done.");
        break;
    }
}

/**
 * Parse a section in the YAML by the given input node + section, setting as
 * many automatic values as possible using our UDA helper system
 */
void parseSection(T)(ref Node node, ref T section) @system
{
    import std.traits : getUDAs, moduleName;

    /* Walk members */
    static foreach (member; __traits(allMembers, T))
    {
        {
            mixin("import " ~ moduleName!T ~ ";");

            mixin("enum udaID = getUDAs!(" ~ T.stringof ~ "." ~ member ~ ", YamlSchema);");
            static if (udaID.length == 1)
            {
                static assert(udaID.length == 1, "Missing YamlSchema for " ~ T.stringof
                        ~ "." ~ member);
                enum yamlName = udaID[0].name;
                enum mandatory = udaID[0].required;
                enum type = udaID[0].type;

                static if (mandatory)
                {
                    enforce(node.containsKey(yamlName), "Missing mandatory key: " ~ yamlName);
                }

                static if (type == YamlType.Single)
                {
                    if (node.containsKey(yamlName))
                    {
                        mixin("setValue(node[yamlName], section." ~ member ~ ", udaID);");
                    }
                }
                else static if (type == YamlType.Array)
                {
                    if (node.containsKey(yamlName))
                    {
                        mixin("setValueArray(node[yamlName], section." ~ member ~ ");");
                    }
                }
            }
        }
    }
}
