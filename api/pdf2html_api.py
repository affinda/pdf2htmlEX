from __future__ import annotations as _annotations

import logging
import os
import pwd
import tempfile
from pathlib import Path
from typing import Optional

import sentry_sdk
from fastapi import FastAPI, HTTPException, Request, UploadFile
from pybase64 import b64encode
from pydantic import BaseModel
from sentry_sdk import set_tag
from fastapi.responses import FileResponse

from api.cmd import run_cmd

logger = logging.getLogger(__name__)

SENTRY_DSN = os.environ.get("SENTRY_DSN_TYPE", default="")
SENTRY_ENABLED = bool(int(os.environ.get("SENTRY_ENABLED", default="0")))
SENTRY_ENVIRONMENT = os.environ.get("SENTRY_ENVIRONMENT", default="pdf2html")
SENTRY_RELEASE = os.environ.get("SENTRY_RELEASE", default="")

if SENTRY_ENABLED:
    if not SENTRY_DSN:
        raise ValueError("SENTRY_ENABLED is set to 1 but SENTRY_DSN is not set")
    logger.info(f"Sentry enabled with SENTRY_DSN = {SENTRY_DSN}")
    sentry_sdk.init(
        dsn=SENTRY_DSN,
        max_breadcrumbs=200,
        attach_stacktrace=True,
        environment=SENTRY_ENVIRONMENT,
        send_default_pii=True,
        traces_sample_rate=0.05,
        enable_tracing=True,
        profiles_sample_rate=0.05,
        max_value_length=10000,  # Default 1024,
        release=SENTRY_RELEASE or None,
    )
    set_tag("host_username", os.environ.get("HOST_USERNAME", default=pwd.getpwuid(os.getuid()).pw_name))

app = FastAPI()


class ConversionFailed(Exception):
    pass




@app.get("/")
async def read_root() -> dict[str, str]:
    return {"data": "This is the root of the Pdf2html API. go to /redoc to view the documentation"}


class DocToConvert(BaseModel):
    doc_b64: Optional[str] = None
    url: Optional[str] = None
    mime_type: Optional[str] = None


@app.post("/convert_doc")
async def convert_pdf(request: Request, file: UploadFile) -> FileResponse:
    doc_identifier = request.headers.get("doc-identifier")
    if doc_identifier:
        sentry_sdk.set_tag("doc_identifier", doc_identifier)

    try:
        with tempfile.TemporaryDirectory() as temp_dir:
            input_file_path = Path(temp_dir, file.filename or "file.pdf")
            output_file_path = input_file_path.with_suffix(".html")
            with open(input_file_path, "wb") as temp_file:
                temp_file.write(await file.read())
            pdf2htmlEX = [
                "pdf2htmlEX",
                "--zoom",
                "1.3",
                "--dest-dir",
                str(temp_dir),
                str(input_file_path),
            ]
            run_cmd(cmd=pdf2htmlEX)
            assert output_file_path.exists()
            return FileResponse(path=output_file_path, filename=output_file_path.name)


    except Exception as exc:
        raise HTTPException(
            status_code=500, detail="PDF2HTML failed to convert, this is extremely rare and should be investigated!"
        ) from exc

