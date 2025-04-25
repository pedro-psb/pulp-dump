import django
django.setup()


import logging
import os 
import asyncio
import time

from pulp_rpm.app.models import RpmRemote
loggers = [logging.getLogger(name) for name in logging.root.manager.loggerDict]
for log in loggers:
    log.setLevel(logging.DEBUG)


REPO_URL="https://dl.fedoraproject.org/pub/epel/9/Everything/x86_64/"
BIG_RPM=f"{REPO_URL}/Packages/a/arm-none-eabi-gcc-cs-12.4.0-1.el9.x86_64.rpm"

remote = RpmRemote(name="tmp_remote", url=REPO_URL)

async def main():
    async def download(url):
        await remote.get_downloader(url=url).run()

    def thread_work():
        for i in range(60):
            print("*", end="", flush=True)
            time.sleep(1)

    loop = asyncio.get_running_loop()
    all_tasks = [download(BIG_RPM), loop.run_in_executor(None, thread_work)]
    await asyncio.gather(*all_tasks)

    # close remote-related aiohttp session
    factory_session = remote.download_factory._session
    await factory_session.close()

asyncio.run(main())
