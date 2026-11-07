#!/usr/bin/env python3

import os
from logging import getLogger
from typing import Any, Dict
import tarfile

from wxflow import (Task, htar,
                    logit, parse_j2yaml, chdir)
# import tarfile
import shutil

logger = getLogger(__name__.split('.')[-1])


class Fetch(Task):
    """Task to pull ROTDIR data from HPSS (or locally)
    """

    def __init__(self, config: Dict[str, Any]) -> None:
        """Constructor for the Fetch task
        The constructor is responsible for collecting necessary yamls based on
        the runtime options and RUN.

        Parameters
        ----------
        config : Dict[str, Any]
            Incoming configuration for the task from the environment

        Returns
        -------
        None
        """
        super().__init__(config)

    @logit(logger)
    def configure(self, fetch_dict: Dict[str, Any]):
        """Determine which tarballs will need to be extracted

        Parameters
        ----------
        fetch_dict : Dict[str, Any]
            Task specific keys, e.g. COM directories, etc

        Return
        ------
        parsed_fetch: Dict[str, Any]
           Dictionary derived from the yaml file with necessary HPSS info.
        """

        fetch_yaml = fetch_dict.FETCH_YAML_TMPL
        fetch_parm = os.path.join(fetch_dict.PARMglobal, "fetch")

        parsed_fetch = parse_j2yaml(os.path.join(fetch_parm, fetch_yaml),
                                    fetch_dict)
        return parsed_fetch

    @logit(logger)
    def execute_pull_data(self, fetchdir_set: Dict[str, Any]) -> None:
        """Pull data from HPSS based on a yaml dictionary and store at the
           specified destination.

        Parameters
        ----------
        fetchdir_set: Dict[str, Any],
            Dict defining set of tarballs to pull and where to put them.

        Return
            None
        """

        f_names = fetchdir_set.target.contents
        if len(f_names) <= 0:     # Abort if no files
            raise FileNotFoundError("FATAL ERROR: The tar ball has no files")

        on_hpss = fetchdir_set.target.on_hpss
        dest = fetchdir_set.target.destination
        tarball = fetchdir_set.target.tarball

        # Select action whether no_hpss is True or not, and pull these
        #    data from tape or locally and place where it needs to go
        # DG - these need testing
        with chdir(dest):
            logger.info(f"Changed working directory to {dest}")

            # Optional local-first retrieval for offline GDAS analysis.
            local_root = self.task_config.get("GDAS_LOCAL_ROOT")
            use_local = (
                self.task_config.get("DO_OFFLINE_ANALYSIS", False)
                in (True, "YES")
                and self.task_config.RUN == "gdas"
                and bool(local_root)
            )

            remaining = []

            for filename in f_names:
                if use_local:
                    relative_path = os.path.normpath(filename)
                    local_file = os.path.join(local_root, relative_path)

                    if os.path.isfile(local_file) and os.path.getsize(local_file) > 0:
                        parent = os.path.dirname(filename)
                        os.makedirs(parent, exist_ok=True)
                        logger.info(
                            f"Copying local analysis: {local_file} -> {filename}"
                        )
                        shutil.copy2(local_file, filename)
                        continue

                    logger.info(
                        f"Local analysis unavailable: {local_file}; "
                        "falling back to configured archive"
                    )

                remaining.append(filename)

            if remaining:
                if on_hpss is True:
                    htar_obj = htar.Htar()
                    htar_obj.xvf(tarball, remaining)
                else:
                    with tarfile.open(tarball, "r") as tar:
                        members = [
                            m for m in tar.getmembers()
                            if m.name in remaining
                        ]
                        tar.extractall(members=members)

            # Verify every required file, including locally copied files.
            missing_files = [
                filename for filename in f_names
                if not os.path.isfile(filename)
                or os.path.getsize(filename) == 0
            ]

            if missing_files:
                raise FileNotFoundError(
                    "Failed to retrieve required files:\n"
                    + "\n".join(missing_files)
                )
