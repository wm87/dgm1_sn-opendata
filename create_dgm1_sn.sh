#!/bin/bash
set -o pipefail

export dbname="dgm1_sn"
export dbport=5432
export dbuser="postgres"
export dbtable="dgm1_sn_import"
export CON=" -d ${dbname} -p ${dbport} -U ${dbuser}"
export OGR="/opt/gdal/bin/ogr2ogr"

export dgm1_sn_import="/bigdata/import/sn/dgm1_sn/dgm1_sn_import.log"

mkdir -p /bigdata/export/dgm1_sn/
rm -R /bigdata/work/dgm1_sn/*
rm /bigdata/export/dgm1_sn/*
rm /bigdata/import/sn/dgm1_sn/*.xyz

psql -c "SELECT pg_terminate_backend(pg_stat_activity.pid),pg_stat_activity.usename,pg_stat_activity.application_name,pg_stat_activity.client_addr,pg_stat_activity.client_hostname,pg_stat_activity.client_port  FROM pg_stat_activity WHERE pg_stat_activity.datname = '$dbname' AND pid <> pg_backend_pid();" $CON
dropdb --if-exists -p $dbport $dbname -U $dbuser
createdb -E UTF8 -T postgis_template -p $dbport $dbname -D $dbtablespace -U $dbuser
psql -c "ALTER DATABASE $dbname SET search_path TO public;" $CON
psql -f create_dgm1_sn.sql $CON

process_zip() {

    zip="$1"
    basename="${zip%.zip}"
    zip_dir="/bigdata/import/sn/dgm1_sn"
    import_dir="/bigdata/import/sn/dgm1_sn/${basename}"
    work_dir="/bigdata/work/dgm1_sn/${basename}"
    mkdir -p $import_dir $work_dir

    echo -e "\nENTPACKEN\n"

    unzip "$zip_dir/$zip" -d "$import_dir"

    for xyz_file in "$import_dir"/*.xyz; do
        sed -i 's/ /,/g' "$xyz_file"
    done

    for xyz_file in "$import_dir"/*.xyz; do
        csv_file="$work_dir/$(basename "${xyz_file%.*}.csv")"
        mv "$xyz_file" "$csv_file"
    done

    for csv_file in "$work_dir"/*.csv; do
        layer_name=$(basename "$csv_file")
        layer_name="${layer_name%????}"
        vrt_file="${csv_file}.vrt"

    cat > "$vrt_file" <<EOF
<OGRVRTDataSource>
    <OGRVRTLayer name="$layer_name">
        <SrcDataSource>$csv_file</SrcDataSource>
        <GeometryType>wkbPoint</GeometryType>
        <LayerSRS>EPSG:25833</LayerSRS>
        <GeometryField encoding="PointFromColumns" x="field_1" y="field_2" z="field_3"/>
        <Field name="field_1" type="Real" nullable="false"/>
        <Field name="field_2" type="Real" nullable="false"/>
        <Field name="field_3" type="Real" nullable="false"/>
    </OGRVRTLayer>
</OGRVRTDataSource>
EOF
    done

    echo "1. Create VectorLayer in PG"
    echo " "

    for csv_file in "$work_dir"/*.csv; do
        echo "$csv_file"

        $OGR -append -f "PostgreSQL" --config PG_USE_COPY YES -ds_transaction \
            -nln ${basename} PG:"dbname='$dbname' port='$dbport' user='$dbuser'" "$csv_file.vrt"

        #rm "$csv_file" "$csv_file.vrt"
    done 2>"$dgm1_sn_import"

    # calculate bbox
    x1=$(cut -d ';' -f2,9 <$import_dir/*.csv | cut -d ' ' -f1 | tr '\n' ' ' | sed -e 's/[^0-9]/ /g' -e 's/^ *//g' -e 's/ *$//g' | tr -s ' ' | sed 's/ /\n/g' | jq -s min)
    y1=$(cut -d ';' -f2,9 <$import_dir/*.csv | cut -d ' ' -f2 | tr '\n' ' ' | sed -e 's/[^0-9]/ /g' -e 's/^ *//g' -e 's/ *$//g' | tr -s ' ' | sed 's/ /\n/g' | jq -s min)
    x2=$(cut -d ';' -f2,9 <$import_dir/*.csv | cut -d ' ' -f3 | tr '\n' ' ' | sed -e 's/[^0-9]/ /g' -e 's/^ *//g' -e 's/ *$//g' | tr -s ' ' | sed 's/ /\n/g' | jq -s max)
    y2=$(cut -d ';' -f2,9 <$import_dir/*.csv | cut -d ' ' -f4 | tr '\n' ' ' | sed -e 's/[^0-9]/ /g' -e 's/^ *//g' -e 's/ *$//g' | tr -s ' ' | sed 's/ /\n/g' | jq -s max)

    echo "bbox: " $x1 $y1 $x2 $y2

    echo " "
    echo "2. Rastern (Vektor nach Raster)"
    /opt/gdal/bin/gdal_rasterize -a field_3 -a_srs EPSG:25833 -tr 1 1 -a_nodata 0.0 -te $x1 $y1 $x2 $y2 -ot Float64 -of GTiff PG:" host=localhost user=$dbuser dbname=$dbname port=$dbport " -sql "SELECT * from ${basename};" /bigdata/export/dgm1_sn/raster_${1%.*}.tif
    psql -c "DROP TABLE IF EXISTS ${basename}" --quiet -p $dbport -d $dbname -U $dbuser
    echo " "

    echo "3 Hillshade / Schummerung"
    /opt/gdal/bin/gdaldem hillshade -of GTiff -az 315 -alt 60 -compute_edges /bigdata/export/dgm1_sn/raster_${1%.*}.tif /bigdata/export/dgm1_sn/hillshade_${1%.*}.tif
    echo " "

    echo " "
    echo "4. Komprimierung"
    /opt/gdal/bin/gdal_translate -of GTiff --config GDAL_TIFF_OVR_BLOCKSIZE 512 -co BLOCKXSIZE=512 -co BLOCKYSIZE=512 -co NUM_THREADS=ALL_CPUS -r cubic -co COMPRESS=DEFLATE -co PREDICTOR=2 -co TILED=YES /bigdata/export/dgm1_sn/hillshade_${1%.*}.tif /bigdata/export/dgm1_sn/small_${1%.*}.tif
    echo " "

    echo " "
    echo "5. Externe Pyramiden (OVR) erstellen"
    /opt/gdal/bin/gdaladdo --config GDAL_CACHEMAX 2048 -r gauss -ro --config COMPRESS_OVERVIEW JPEG --config INTERLEAVE_OVERVIEW PIXEL /bigdata/export/dgm1_sn/small_${1%.*}.tif 2 4 8 16 32 64
    echo " "

    echo " "
    echo "6. Cleaner"
    rm /bigdata/export/dgm1_sn/raster_${1%.*}.tif
    rm /bigdata/export/dgm1_sn/hillshade_${1%.*}.tif
    rm -R $import_dir $work_dir
    echo "---------------------------------------"
}
export -f process_zip

cd /bigdata/import/sn/dgm1_sn/
parallel -j 6 process_zip ::: *.zip

gdalbuildvrt /bigdata/export/dgm1_sn/dgm1.vrt /bigdata/export/dgm1_sn/small_*.tif

psql -c "SELECT pg_terminate_backend(pg_stat_activity.pid),pg_stat_activity.usename,pg_stat_activity.application_name,pg_stat_activity.client_addr,pg_stat_activity.client_hostname,pg_stat_activity.client_port  FROM pg_stat_activity WHERE pg_stat_activity.datname = '$dbname' AND pid <> pg_backend_pid();" $CON
dropdb --if-exists -p $dbport $dbname -U $dbuser
