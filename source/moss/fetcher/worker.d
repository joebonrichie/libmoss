/*
 * This file is part of moss-fetcher.
 *
 * Copyright © 2020-2021 Serpent OS Developers
 *
 * This software is provided 'as-is', without any express or implied
 * warranty. In no event will the authors be held liable for any damages
 * arising from the use of this software.
 *
 * Permission is granted to anyone to use this software for any purpose,
 * including commercial applications, and to alter it and redistribute it
 * freely, subject to the following restrictions:
 *
 * 1. The origin of this software must not be misrepresented; you must not
 *    claim that you wrote the original software. If you use this software
 *    in a product, an acknowledgment in the product documentation would be
 *    appreciated but is not required.
 * 2. Altered source versions must be plainly marked as such, and must not be
 *    misrepresented as being the original software.
 * 3. This notice may not be removed or altered from any source distribution.
 */

module moss.fetcher.worker;

import etc.c.curl;
import core.sync.mutex;
import std.exception : enforce;
import moss.fetcher : Fetcher;
import moss.core.fetchcontext : Fetchable;

/**
 * The worker preference defines our policy in fetching items from the
 * FetcherQueue, i.e small or big
 */
package enum WorkerPreference
{
    /**
     * This worker prefers small items
     */
    SmallItems = 0,

    /**
     * This worker prefers large items
     */
    LargeItems,
}

/**
 * A FetchWorker is created per thread and maintains its own CURL handles
 */
package final class FetchWorker
{

    @disable this();

    /**
     * Construct a new FetchWorker and setup any associated resources.
     */
    this(CURLSH* shmem, WorkerPreference preference = WorkerPreference.SmallItems)
    {
        assert(shmem !is null);
        this.shmem = shmem;
        this.preference = preference;

        /* Grab a handle. */
        handle = curl_easy_init();
        enforce(handle !is null, "FetchWorker(): curl_easy_init() failure");

        setupHandle();

        /* Establish locks for CURLSH usage */
        dnsLock = new shared Mutex();
        sslLock = new shared Mutex();
        conLock = new shared Mutex();
    }

    /**
     * Close down this worker resources
     */
    void close()
    {
        if (handle is null)
        {
            return;
        }
        curl_easy_cleanup(handle);
        handle = null;
    }

    /**
     * Lock a specific mutex for CURL sharing
     */
    void lock(CurlLockData lockData) @safe @nogc nothrow
    {
        switch (lockData)
        {
        case CurlLockData.dns:
            dnsLock.lock_nothrow();
            break;
        case CurlLockData.ssl_session:
            sslLock.lock_nothrow();
            break;
        case CurlLockData.connect:
            conLock.lock_nothrow();
            break;
        default:
            break;
        }
    }

    /**
     * Unlock a specific mutex for CURL sharing
     */
    void unlock(CurlLockData lockData) @safe @nogc nothrow
    {
        switch (lockData)
        {
        case CurlLockData.dns:
            dnsLock.unlock_nothrow();
            break;
        case CurlLockData.ssl_session:
            sslLock.unlock_nothrow();
            break;
        case CurlLockData.connect:
            conLock.unlock_nothrow();
            break;
        default:
            break;
        }
    }

    /**
     * Run using the current fetch queue
     */
    void run(scope Fetcher fetcher)
    {
        while (true)
        {
            auto fetchable = fetcher.allocateWork(preference);
            if (fetchable.isNull)
            {
                break;
            }
        }
    }

private:

    /**
     * Set the baseline handle options
     */
    void setupHandle()
    {
        CURLcode ret;

        /* Setup share */
        ret = curl_easy_setopt(handle, CurlOption.share, shmem);
        enforce(ret == 0, "FetchWorker.setupHandle(): Failed to set SHARE");

        /* Setup write callback */
        ret = curl_easy_setopt(handle, CurlOption.writefunction, &mossFetchWorkerWrite);
        enforce(ret == 0, "FetchWorker.setupHandle(): Failed to set WRITEFUNCTION");
        ret = curl_easy_setopt(handle, CurlOption.writedata, this);
        enforce(ret == 0, "FetchWorker.setupHandle(): Failed to set WRITEDATA");

        /* Setup progress callback */
        ret = curl_easy_setopt(handle, CurlOption.progressfunction, &mossFetchWorkerProgress);
        enforce(ret == 0, "FetchWorker.setupHandle(): Failed to set PROGRESSFUNCTION");
        ret = curl_easy_setopt(handle, CurlOption.progressdata, this);
        enforce(ret == 0, "FetchWorker.setupHandle(): Failed to set PROGRESSDATA");

        /* Enable progress reporting */
        ret = curl_easy_setopt(handle, CurlOption.noprogress, 0);
        enforce(ret == 0, "FetchWorker.setupHandle(): Failed to set NOPROGRESS");
    }

    /**
     * Handle writing
     */
    extern (C) static size_t mossFetchWorkerWrite(void* ptr, size_t size,
            size_t nMemb, void* userdata)
    {
        return nMemb;
    }

    /**
     * Handle the progress callback
     */
    extern (C) static void mossFetchWorkerProgress(void* userptr,
            double dlTotal, double dlNow, double ulTotal, double ulNow)
    {
        auto worker = cast(FetchWorker) userptr;
        enforce(worker !is null, "CURL IS BROKEN");

        /* TODO: Report this. */
        immutable auto percentDone = dlNow / dlTotal * 100.0;
    }

    /**
     * Reusable handle
     */
    CURL* handle;

    /**
     * Shared data for CURL handles
     */
    CURLSH* shmem;

    /**
     * Lock for sharing DNS
     */
    shared Mutex dnsLock;

    /**
     * Lock for sharing SSL session
     */
    shared Mutex sslLock;

    /**
     * Lock for sharing connections
     */
    shared Mutex conLock;

    /**
     * By default prefer small items
     */
    WorkerPreference preference = WorkerPreference.SmallItems;
}
