/*
 * SPDX-FileCopyrightText: Copyright © 2020-2022 Serpent OS Developers
 *
 * SPDX-License-Identifier: Zlib
 */

/**
 * moss.db.keyvalue.orm
 *
 * Compile time ORM support for moss-db
 *
 * Authors: Copyright © 2020-2022 Serpent OS Developers
 * License: Zlib
 */

module moss.db.keyvalue.orm;

public import moss.db.keyvalue.errors;
public import moss.db.keyvalue.interfaces;
public import moss.db.keyvalue.orm.types;

/**
 * Save the object in the current transaction
 *
 * Params:
 *      M = Model
 *      obj = Model object
 *      tx = Read-write transaction
 * Returns: A DatabaseResult sumtype, check for errors
 */
public DatabaseResult save(M)(ref M obj, scope Transaction tx) @safe
        if (isValidModel!M)
{
    return NoDatabaseError;
}

@("Basic type testing") @safe unittest
{
    @Model static struct User
    {
        @PrimaryKey int id;
        string username;
    }

    immutable auto one = User(2, "bobby");

    static assert(isValidModel!User, "User should be a valid model");
    static assert(modelName!User == "users", "Invalid model name, got: " ~ modelName!User);
    immutable auto expRow = [46, 117, 115, 101, 114, 46, 0, 0, 0, 0, 2];
    assert(rowName(one) == expRow);
}
