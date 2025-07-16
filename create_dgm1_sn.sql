DROP TABLE  IF EXISTS public.dgm1_sn_import;

CREATE TABLE public.dgm1_sn_import
(
    ogc_fid serial NOT NULL,
    field_1 double precision NOT NULL,
    field_2 double precision NOT NULL,
    field_3 double precision NOT NULL,
    wkb_geometry geometry(Point,25833),
    CONSTRAINT dgm1_sn_import_pkey PRIMARY KEY (ogc_fid)
)
WITH (
    OIDS = FALSE
)
TABLESPACE tbl_bigdata;

ALTER TABLE public.dgm1_sn_import
    OWNER to postgres;

-- Index: dgm1_sn_wkb_geometry_geom_idx

-- DROP INDEX public.dgm1_sn_wkb_geometry_geom_idx;

CREATE INDEX dgm1_sn_import_wkb_geometry_geom_idx
    ON public.dgm1_sn_import USING gist
    (wkb_geometry)
    TABLESPACE tbl_bigdata;
