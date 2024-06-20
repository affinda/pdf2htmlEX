from __future__ import annotations as _annotations

import logging
import os
import subprocess
import sys
from pathlib import Path
from typing import Dict, List, Literal, Optional, Tuple, Union, overload


logger = logging.getLogger(__name__)


class CalledCommandError(Exception):
    def __init__(
        self,
        returncode: int,
        cmd: Union[str, List[str]],
        cwd: Optional[Union[str, Path]],
        stdout: Optional[str],
        stderr: Optional[str],
    ) -> None:
        self.returncode = returncode
        self.cmd = cmd
        self.cwd = str(cwd)
        self.stdout = stdout
        self.stderr = stderr
        self.message = f"Called cmd {cmd} failed with returncode {returncode}"
        logger.error(
            f"{self.message} \n"
            f"stdout:\n{stdout} \n"
            f"stderr:{stderr} \n"
            f"cmd_str: {' '.join(cmd) if isinstance(cmd, List) else cmd} \n"
            f"cwd: {self.cwd}"
        )
        super().__init__(self.message)


@overload
def run_cmd(
    cmd: Union[str, List[str]],
    *,
    capture_output: Literal[False] = False,
    cwd: Optional[Union[Path, str]] = None,
    extra_env: Optional[Dict[str, str]] = None,
    input: Optional[Union[bytes, str]] = None,
    text: bool = True,
    stdout_to_stderr: bool = False,
    timeout: Optional[int] = None,
) -> Tuple[None, None]: ...


@overload
def run_cmd(
    cmd: Union[str, List[str]],
    *,
    capture_output: Literal[True],
    cwd: Optional[Union[Path, str]] = None,
    extra_env: Optional[Dict[str, str]] = None,
    input: Optional[Union[bytes, str]] = None,
    text: bool = True,
    stdout_to_stderr: Literal[False] = False,  # stdout_to_stderr is not currently supported when capture_output is set
    timeout: Optional[int] = None,
) -> Tuple[str, str]:  # If capture_output is True, will return output
    ...


# noinspection PyShadowingBuiltins
def run_cmd(
    cmd: Union[str, List[str]],
    *,
    capture_output: Literal[True, False] = False,
    cwd: Optional[Union[Path, str]] = None,
    extra_env: Optional[Dict[str, str]] = None,
    input: Optional[Union[bytes, str]] = None,
    text: bool = True,
    stdout_to_stderr: bool = False,
    timeout: Optional[int] = None,
) -> Tuple[Optional[str], Optional[str]]:
    """
    Runs a cmd and returns its output, allowing the capturing of output and specifying a new environment vars for the
    command to run in.
    :param cmd: Either a string cmd for shell, or a list of args to be run outside of a shell
    :param cwd: Working directory of the process, else will be run in the current working directory
    :param extra_env: Dict of extra env to add to the subprocess
    :param capture_output:  If true, will capture output and store it at p.stdout / p.stderr
    :param input: str or bytes to pass as contents of subprocess' stdin
    :param text: If true, stdout/stderr will be returned as strings rather than bytes
    :param stdout_to_stderr: If true, stdout will be redirected to stderr
    :param timeout: Time in seconds to wait before raising TimeoutExpired
    :returns Tuple of (stdout, stderr) if capture_output is True, else (None, None)
    :raises CalledCommandError: If command does not complete with exit code == 0
    """
    shell = True if isinstance(cmd, str) else False

    if isinstance(cwd, Path):
        cwd = str(cwd.absolute())

    logger.debug(f"Running cmd: \n{cmd}")
    if extra_env:
        updated_env = os.environ.copy()
        updated_env.update(extra_env)
    else:
        updated_env = None

    # Gevent's patched subprocess.run checks for the presence of stdout kwargs, not whether or not they are None, hence
    # this if statement instead of just passing stdout=None
    if not capture_output and stdout_to_stderr:
        p = subprocess.run(
            cmd,
            shell=shell,
            cwd=cwd,
            env=updated_env,
            check=False,
            capture_output=capture_output,
            text=text,
            timeout=timeout,
            input=input,
            stdout=sys.stderr.fileno(),
        )
    else:
        p = subprocess.run(
            cmd,
            shell=shell,
            cwd=cwd,
            env=updated_env,
            check=False,
            capture_output=capture_output,
            text=text,
            timeout=timeout,
            input=input,
        )
    if p.returncode != 0:
        raise CalledCommandError(returncode=p.returncode, cmd=cmd, cwd=cwd, stdout=p.stdout, stderr=p.stderr)
    if capture_output:
        return p.stdout.rstrip(), p.stderr.rstrip()
    else:
        return None, None
