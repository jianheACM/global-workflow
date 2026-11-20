############################
Global Forecast System (GFS)
############################

========
Overview
========

The Global Forecast System (GFS) is the flagship NOAA NWP model and produces a coupled global analysis and forecast for use in medium-range forecasting. GFS supports many different coupling and data assimilation configurations.

============
Key Features
============

* 3D-EnVar atmospheric data assimilation using both legacy GSI and new JEDI-based system
* 3D-EnVar coupled data assimilation via JEDI
* Fully coupled forecast with atmosphere, ocean, ice, and waves
* Wide range of supported resolutions
* Gridded forecasts on a variety of output grids
* Model forecast soundings
* Point wave forecasts
* MET-plus-based forecast verification (on select platforms)
* Archival to NOAA tape storage (HPSS) where available

============
GFS Workflow
============

GFS runs in multiple phases: an 'early' *gfs* phase, which in operations runs shortly after the initialization time, and a 'late' *gdas* phase, run later that includes late-arriving observations. The gfs phase produces an initial analysis using obs available at the time, which it then uses for initial conditions for the main GFS forecast. The gdas phase produces a new analysis incoroprating the late observations and runs the DA ensemble to produce background error covariances for the next cycle. Starting with GFS v17, the DA ensemble will also be run in the early (gfs) phase to provide improved initial conditions to GEFS.

For consistency, GFS uses this same pattern in development mode. Two sets of observations are preserved in the :ref:`_dump_archive <global dump archive>`, one with those observations available for the early phase, and one with those available for the late phase.

The GFS configuration in the GW is organized into a series of jobs that run in a defined sequence for each cycle. These jobs handle everything from preparing input data to running the forecast and generating post processed products. Each job is executed by a workflow manager (rocoto or ecFlow) and corresponds to a specific script within the workflow. Although the exact list of jobs varies depending on whether you are running gdas, gfs, or a specialized experiment, the major categories of jobs include:

1. **Preprocessing Jobs**:

These jobs prepare all required inputs before analysis or forecasting begins and examples include:

  - **prep**: runs data preprocessing prior to the analysis
  - **stage_ic**: stages the initial conditions needed to start the forecast
  - **waveinit/waveprep**: wave model initialization and preprocessing (when waves are enabled)

2. **Analysis Jobs (gdas phase)**:
These jobs perform data assimilation to produce the best estimate of the atmosphere at the cycle time and examples include:

  - **anal**: runs the atmospheric analysis (GSI) to produce analysis increments and update the surface guess
  - **analcalc**: adds the analysis increments to the previous cycle's forecast to produce the atmospheric analysis files
  - **analdiag**: creates netCDF diagnostic files (observation values, innovations, errors, QC)
  - **EnKF jobs (eobs, eupd, ecenN, esfc, efcs)**: Ensemble Kalman Filter (ENKF) data assimilation (when running cycled with an ensemble)
  - **updatebc**: updates background fields for the next cycle

3. **Forecast Jobs (gfs phase)**:
These jobs run the UFS-WM to produce the forecast and these jobs include:

  - **fcst**: main forecast model integration
  - **atmupp**: runs UPP on model output

4. **Post processing Jobs**:
These jobs generate downstream products used for verification, graphics, or distribution and examples include:

  - **atmos_prod**: regrids atmosphere forecast to lat-lon grids
  - **wave post jobs (wavepostsbs, wavepostpnt, wavepostbndpnt, wavepostbndpntbll)**: wave post-processing
  - **metp**: MET/METplus verification via EMC_verif-global
  - **awips / gempak**: downstream AWIPS and GEMPAK products (operations only; not normally run in experiments)

5. **Archiving and Cleanup Jobs (Experimental Mode Only)**:
These jobs are run only in development mode and examples include:

  - **arch_vrfy**: archives verification products
  - **arch_tars**: archives tarred workflow outputs (e.g., logs, restarts)
  - **cleanup**: removes temporary or intermediate files

In development, the workflow is managed by the rocoto workflow manager, with tasks defined in the
``dev/workflow/rocoto/gfs_tasks.py`` file.

For a list of descriptions for all jobs, see :ref:`job_descriptions`.

.. _gfs_config_files:

===================
Configuration Files
===================

GFS configuration is primarily managed through the config files in the ``dev/parm/config/gfs`` directory. Core settings and those related to job flow are located in ``config.base``, with the most common settings additionally parameterized to be filled in at experiment creation time. Job resources (cores, memory, etc.) are defined in ``config.resources`` with machine-specific overrides in the corresponding version for the machine. Beyond those, each job (or class of jobs) has its own config file for that job's settings.

===============
Output Products
===============

* Early and late analysis at model resolution
* EnKF ensemble to provide background errors and initial conditions for GEFS
* Data assimilation verification diagnostics
* grib2 gridded atmosphere forecast on various grids
* forecast model soundings
* NetCDF marine gridded forecast
* wave gridded and point forecasts
* MET-plus-based forecast verification

============================================
Experimental vs Operational Runs: A Snapshot
============================================

Experimental run is different from operational runs in the following ways:

* **Workflow manager**:

  - Operations use `ecFlow <https://www.ecmwf.int/en/learning/training/introduction-ecmwf-job-scheduler-ecflow>`__, whereas development use `rocoto <https://github.com/christopherwharrop/rocoto/wiki/documentation>`__.

.. note::

   Experiments can also be run with ecFlow if the platform has an ecFlow server.

* **Dump step**:

  - Not run in experiments but in real-time production. Dump data already exists in GDA on supported platforms.

* **Additional steps** in experimental mode:

  - **arch_vrfy**
  - **arch_tars**
  - **cleanup**

^^^^^^^^^^^^^^^^^^^
For New Users
^^^^^^^^^^^^^^^^^^^
.. note::

  - Operational systems include many additional downstream jobs that are not run in development mode.
  - The workflow manager (rocoto or ecFlow) determines job dependencies and ensures each job runs only when its prerequisites are complete.
  - The exact job list for your experiment is defined in the workflow XML (rocoto) or suite definition (ecFlow)

C384 AM4 air-quality experiments
================================

Use the global-workflow ``dev-stretch`` branch as the base for these
experiments. The configuration changes were prepared against ``31170d6e``,
which pins UFS Weather Model ``607bc1fa`` and UFS_UTILS ``217ffb2d``.
When installing the configuration from the companion Git patch, start
from a clean checkout of ``dev-stretch`` and apply it with
``git am /path/to/ufs-chem-c384-native-dev-stretch.patch``.
Use the submodule revisions recorded by the branch when building the model
and preparing the grids.

Use the atmosphere-only AM4 executable with the two offline cycling presets.
Each experiment runs six-hour GDAS cycles and daily GFS forecasts. Both grids
use 128 interfaces (127 model layers), a 16 × 16 FV3 layout per face, and two
threads. The stretched preset applies Schmidt stretching with a factor of 2.0
centered at 38.5°N, 97.5°W and uses a 150-second time step. The uniform preset
uses a 300-second time step.

From the repository root, pass the matching IC root to each launcher.

.. code-block:: bash

   bash dev/workflow/setup_c384_am4.sh /path/to/uniform_ics
   bash dev/workflow/setup_c384stre_am4.sh /path/to/stretched_ics

The launchers default to a cold GDAS start at 2023051500 and the first GFS
forecast at 2023051506. Override ``IDATE``, ``SDATE_GFS``, and ``EDATE`` to
choose the cycling window. The first GFS forecast needs a preceding six-hour
GDAS forecast. Set ``EDATE`` beyond the first GFS cycle for additional daily
forecasts. Append ``--submit`` to initiate Rocoto submission after setup.

For the default cold start, each IC root must provide its own
``gdas.20230515/00/model/atmos/input/`` directory containing ``gfs_ctrl.nc``,
six ``gfs_data.tile*.nc`` files with AM4 tracers, and six matching
``sfc_data.tile*.nc`` files. Use ICs generated for each experiment's grid and
vertical coordinate. After the initial cycle, the offline analysis tasks use
external GDAS atmospheric and surface analyses, retrieved by the existing
offline fetch workflow, and the previous GDAS forecast.

The C384 stretched preset selects the MOM6-masked static product under
``/scratch4/BMC/rcm1/jhe/ufschem/inputdata/fix_stretch/static_C384_s2_mx025/C384``. It reads ``C384_mosaic.nc``, six
``C384_grid.tile*.nc`` files, six ``C384.mx025_oro_data.tile*.nc`` files,
and matching ``C384.mx025.*.tile*.nc`` climatologies in ``sfc/``. Set ``STRETCH_FIX_OROG`` to the versioned
directory above ``C384/``. To use the atmosphere-only static product instead, set
``STRETCH_STATIC_SET: "atmos"`` and point ``STRETCH_FIX_OROG`` at its parent
directory, such as ``<static_run>/atmos``. Its orography and surface prefix
is ``C384``. Use the same selection for GDAS meteorological IC
generation, GDAS surface cycling, and forecasts.

The GWD tile root defaults to the selected orography tree and contains
``C384_oro_data_ls.tile*.nc`` and ``C384_oro_data_ss.tile*.nc`` under
``C384/``. The preset reads the shared ``ugwp_limb_tau.nc`` through
``STRETCH_UGWP_LIMB_TAU``. For another dataset with separate GWD tiles,
set ``STRETCH_FIX_UGWD`` to their root. The other terrain, land-cover, and
lake links under ``fix_stretch/`` are inputs to static-file generation.
The uniform preset uses the standard ``fix/orog`` and ``fix/ugwd`` trees.

The MOM6-masked product can also serve as the FV3 atmospheric static dataset
for a future coupled configuration using the same ocean mask. The stretched
workflow currently supports ``APP=ATM``. Coupled S2S also needs a stretched
coupled ``grid_spec.nc``, consistent ocean and ice mesh and initial conditions,
and a validated coupled workflow configuration.

The grid settings are independent of chemistry. In the setup YAML, use
``base.DO_STRETCH`` to enable Schmidt stretching and ``base.FV3_GRID_ID`` to label
the resulting grid for input staging. ``CASE`` stays ``C384`` for model sizing
and fixed-file basenames. The default grid ID is ``C384stre`` when stretched and
``C384`` when uniform. To use a different stretched grid, set its grid ID,
factor, and center together with its fixed-file roots. For example, the
CONUS preset can be configured as follows.

.. code-block:: yaml

   base:
     DO_STRETCH: "YES"
     GFS_OUTPUT_GRID: "cubed_sphere_grid"
     FV3_GRID_ID: "C384stre"
     FV3_STRETCH_FACTOR: "2.0"
     FV3_TARGET_LAT: "38.5"
     FV3_TARGET_LON: "-97.5"
     STRETCH_FIX_OROG: "/scratch4/BMC/rcm1/jhe/ufschem/inputdata/fix_stretch/static_C384_s2_mx025"
     STRETCH_STATIC_SET: "masked"
     STRETCH_OCNRES: "025"
     STRETCH_UGWP_LIMB_TAU: "/scratch4/BMC/rcm1/jhe/ufschem/inputdata/fix_stretch/ugwp_limb_tau.nc"
     DO_CATChem: "YES"
     DO_AM4CHEM: "YES"
   prepchem:
     AM4_EMISSIONS_ROOT: "/path/to/emi_C384stre"
     AM4_EMI2_ROOT: "/path/to/emi_C384stre"

Merge these keys into the matching sections of an experiment preset. For a
chemistry-free GFS forecast, set both chemistry switches to ``"NO"``. The
stretch configuration currently supports atmosphere-only C384 and uses the
C384 stretched time step and drag settings. Match the factor and center to
those used to generate the fixed fields and ICs.

AM4 uses ``FV3_GRID_ID`` for the emissions and fire root suffix and for the
``FAge`` and ``Depvel`` subdirectories. Configure AM4-specific paths under
``prepchem``, including ``AM4_INPUT_ROOT``, ``AM4_FIRE_ROOT``, ``AM4_AGE_DIR``,
``AM4_DEPVEL_DIR``, and ``AM4_SUPPORT_DIR``. Put stretched ``EMI2`` and
``fengsha_2023/12month`` under the stretched emissions root, or set
``prepchem.AM4_EMI2_ROOT`` to their common parent. Provide six matching tiles
for each grid-dependent product, including aircraft emissions if enabled.
Non-AM4 CATChem uses ``prepchem.EMIIN`` as the parent of
``emi_<FV3_GRID_ID>``. Each chemistry scheme still requires its own input
products and runtime validation on the selected grid.

Both presets select ``base.GFS_OUTPUT_GRID: "cubed_sphere_grid"`` with one
NetCDF file per face. For each forecast hour, use
``gfs.t00z.atm.fHHH.tile1.nc`` through ``tile6.nc`` and the matching
``gfs.t00z.sfc.fHHH.tile*.nc`` under
``gfs.YYYYMMDD/00/model/atmos/history``. This mode writes one history stream
and skips inline UPP, downstream atmospheric products, and verification
archiving. Cleanup waits for the forecast, removes its work directory, and
retains the COM output. Standard COM archiving is unavailable in this
GFS output mode.

GDAS keeps its Gaussian output because the offline analysis reads both
``atm.f006.nc`` and ``sfc.f006.nc`` from the previous GDAS forecast. The
stretched experiment still integrates GDAS on the stretched grid.

Experiments using the default ``gaussian_grid`` retain the standard output and
workflow. In that mode, ``base.DO_HISTORY_FILE_ON_NATIVE_GRID: "YES"`` adds a
second, native history stream. For a first stretched cycle, check
``input.nml`` for the Schmidt settings and verify the denser target grid
from the history coordinates. Use each experiment's own coordinates for
station or satellite collocation.
