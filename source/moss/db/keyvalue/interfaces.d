/*
 * SPDX-FileCopyrightText: Copyright © 2020-2022 Serpent OS Developers
 *
 * SPDX-License-Identifier: Zlib
 */

/**
 * moss.db.keyvalue.interfaces
 *
 * API design for the project (inspired heavily by boltdb)
 *
 * Authors: Copyright © 2020-2022 Serpent OS Developers
 * License: Zlib
 */

module moss.db.keyvalue.interfaces;

import moss.db.keyvalue.errors;

/**
 * Readable sources
 */
public interface Readable
{
    /**
     * Retrieve current value indicated by key
     */
    DatabaseError get(in ubyte[] key, out ubyte[] value) @safe;
}

/**
 * Writable targets
 */
public interface Writable
{
    /**
     * Set `key` to `value`
     */
    DatabaseError set(in ubyte[] key, in ubyte[] value) @safe;

    /**
     * Remove key / value pair from storage
     */
    DatabaseError remove(in ubyte[] key) @safe;
}

/**
 * Buckets extend Read/Write functionality into a container
 */
public interface Bucket : Readable, Writable
{

}

/**
 * Transactions are obtained from the root database.
 */
public interface Transaction : Readable, Writable
{
    /**
     * Retrieve a bucket from the transaction
     */
    DatabaseError bucket(in ubyte[] prefix, void delegate(scope Bucket) @safe bucketCall) @safe;
}

/**
 * Manual transactions offer more granularity.
 */
public interface ManualTransaction : Transaction
{

    /**
     * Try to commit the transaction
     */
    DatabaseError commit() @safe;

    /**
     * Try to rollback the transaction
     */
    DatabaseError rollback() @safe;
}

/**
 * Databases support implicit + explicit transactions.
 */
public interface GenericDatabase
{
    /**
     * Access a bucket in the DB
     */
    DatabaseError bucket(in ubyte[] prefix, void delegate(scope Bucket) bucketCall) const;

    /**
     * Start read only transaction of the DB
     */
    DatabaseError view(void delegate(in Transaction tx) @safe) const nothrow;

    /**
     * Start read-write transaction of the DB
     */
    DatabaseError update(void delegate(scope Transaction tx));

    /**
     * Start a new transaction that is manually controlled.
     */
    ManualTransaction begin();
}
