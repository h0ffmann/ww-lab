#!/usr/bin/env python3
"""Download ERA5 10 m winds for example 02 from the Copernicus CDS.

Requires a free CDS account and an API key in ~/.cdsapirc:
    https://cds.climate.copernicus.eu/how-to-api

    pip install cdsapi

The dataset name and request schema changed when CDS moved to the new
Climate Data Store (CDS-Beta -> CDS) infrastructure. If this errors, copy
the request straight off the dataset's download page -- it generates the
exact Python snippet for you, and that is always more current than any
script someone wrote months earlier.
"""

import cdsapi

AREA = [-24, -52, -32, -44]  # N, W, S, E  -- note CDS ordering

c = cdsapi.Client()
c.retrieve(
    "reanalysis-era5-single-levels",
    {
        "product_type": ["reanalysis"],
        "variable": ["10m_u_component_of_wind", "10m_v_component_of_wind"],
        "year": ["2024"],
        "month": ["07"],
        "day": [f"{d:02d}" for d in range(1, 9)],
        "time": [f"{h:02d}:00" for h in range(24)],
        "area": AREA,
        "data_format": "netcdf",
        "download_format": "unarchived",
    },
    "era5_winds.nc",
)
print("wrote era5_winds.nc")
print("now check it:  ncdump -h era5_winds.nc | head -40")
