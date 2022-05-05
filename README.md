# DSS C-API: An unofficial C API for EPRI's OpenDSS (Felipe's Version)
> This is a fork of DSS Extensions's [DSS C-API](https://github.com/dss-extensions/dss_capi) and is not related to the [DSS Extensions](https://github.com/dss-extensions) or EPRI.

> As explicit in [`LICENSE`](LICENSE), this code uses the same license as the original code, LGPL 2.1 or later.

The main objective of this fork is to have a version of the [DSS C-API](https://github.com/dss-extensions/dss_capi) for other projects that do not require COM compatibilities.

The `master` branch will keep as a mirror of the DSS Extensions's [DSS C-API](https://github.com/dss-extensions/dss_capi) `master` branch, but the other branches could have some differences.

The releases made in this repository will be based on the `felipe-version` branch, which depends on the (KLUSolveX _Felipe's Version_)[https://github.com/felipemarkson/klusolve] as a static dependency and uses the same LPGL [`LICENSE`](LICENSE) of (KLUSolveX _Felipe's Version_)[https://github.com/felipemarkson/klusolve]. See [`LICENSE`](LICENSE)


## Credits

The [DSS C-API](https://github.com/dss-extensions/dss_capi) was originally made by [DSS Extensions](https://github.com/dss-extensions). See [`ORIGINAL_LICENSE`](ORIGINAL_LICENSE) for more details.

This project is derived from EPRI's OpenDSS. See `OPENDSS_LICENSE`. Also, check each subfolder for more details.

Note that, since OpenDSS depends on KLU via KLUSolve, the KLU licensing conditions (LGPL or GPL, depending on how you build KLU) apply to the resulting binaries; from the DSS-Extension KLUSolve repository, check the files `klusolve/COPYING`, `klusolve/lgpl_2_1.txt`, the SuiteSparse documentation and the Eigen3 documentation.