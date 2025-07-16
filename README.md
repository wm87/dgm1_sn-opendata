# DGM1 Sachsen – Automatisierte Verarbeitungspipeline

Dieses Projekt bietet eine vollautomatische Shell-Pipeline zur Verarbeitung des **Digitalen Geländemodells 1 (DGM1)** für den Freistaat Sachsen. Es umfasst das Extrahieren, Konvertieren, Importieren, Rasterisieren und Visualisieren von Höhendaten mithilfe von **PostGIS** und **GDAL**.

## Features

* Automatischer Datenimport aus `.zip`-Dateien
* Konvertierung von XYZ nach CSV + VRT
* Laden in PostgreSQL/PostGIS
* Rasterisierung der Punktdaten (1m Auflösung)
* Erzeugung von Hillshade-Darstellungen (Schummerungen)
* TIF-Komprimierung und Overviews
* Parallele Verarbeitung via GNU Parallel
* Erstellung einer VRT-Datei als Mosaik für QGIS

---

## Verzeichnisstruktur

```bash
/bigdata/
├── import/sn/dgm1_sn/       # Eingangsdaten (.zip mit .xyz)
├── work/dgm1_sn/            # Temporäre Arbeitsdaten
└── export/dgm1_sn/          # Ausgabe: TIF, Hillshade, Pyramiden
```

---

## Voraussetzungen

* **PostgreSQL mit PostGIS-Erweiterung**
* **GDAL** (inkl. `ogr2ogr`, `gdal_rasterize`, `gdaldem`, `gdal_translate`, `gdaladdo`)
* **GNU Parallel**
* **JQ**
* Eine vorbereitete SQL-Datei: `create_dgm1_sn.sql`

---

## Konfiguration (Variablen im Skript)

```bash
export dbname="dgm1_sn"
export dbport=5432
export dbuser="postgres"
export dbtable="dgm1_sn_import"
export dgm1_sn_import="/bigdata/import/sn/dgm1_sn/dgm1_sn_import.log"
```

---

## Ablauf der Verarbeitung

1. **Vorbereitung**

   * Leeren der Verzeichnisse
   * Zurücksetzen der Datenbank

2. **ZIP-Dateien verarbeiten**
   Für jede Datei:

   * Entpacken
   * `.xyz` → `.csv` (mit Komma-Trennung)
   * Erstellung einer `.vrt`-Datei pro CSV

3. **Import in PostgreSQL/PostGIS**

   * Über `ogr2ogr` mit VRT-Dateien

4. **Rasterisierung**

   * 1m Auflösung aus Punktdaten
   * Bounding Box automatisch berechnet

5. **Hillshade-Erstellung**

   * mit `gdaldem hillshade`

6. **GeoTIFF-Optimierung**

   * Kompression + Tiling

7. **Pyramiden (Overviews)**

   * Für schnelle Darstellung in GIS-Software

8. **Bereinigung**

   * Entfernen temporärer Daten
   * Entfernen von Zwischen-TIFFs

9. **Mosaik-Erstellung**

   * Erzeugung einer `.vrt` aus allen kleinen TIF-Dateien

---

## Nutzung

### Schritt 1: Eingangsdaten bereitstellen

Lege deine `.zip`-Dateien mit XYZ-Dateien in folgendes Verzeichnis:

```bash
/bigdata/import/sn/dgm1_sn/
```

### Schritt 2: Skript ausführen

```bash
bash create_dgm1_sn.sh
```

> Stelle sicher, dass das Skript ausführbar ist:
>
> ```bash
> chmod +x create_dgm1_sn.sh
> ```

---

## Beispiel: Ausgabe-Dateien

* `/bigdata/export/dgm1_sn/small_*.tif` – optimierte Hillshade-TIFFs
* `/bigdata/export/dgm1_sn/dgm1.vrt` – Mosaik aller Einzel-TIFFs

Diese Dateien können direkt in QGIS oder ArcGIS geladen werden.

---

## Hinweise

* Koordinatensystem: **ETRS89 / UTM Zone 33N (EPSG:25833)**
* Die ursprünglichen XYZ-Dateien enthalten die Spalten: `X Y Z`
* Rasterisierung verwendet Z-Werte (Höhe)

---

## Datenquelle

* DGM1-Daten (XYZ als `.zip`-Pakete) können über das offizielle Geoportal Sachsen bezogen werden:
  [https://www.geodaten.sachsen.de/batch-download-4719.html](https://www.geodaten.sachsen.de/batch-download-4719.html)

---

## Lizenz

Dieses Projekt steht unter der **Apache License Version 2.0**. Siehe [LICENSE](./LICENSE) für Details.

---

## Autor

\[Dein Name] – \[[dein.email@example.com](mailto:dein.email@example.com)]
[GitHub-Profil](https://github.com/deinbenutzername)

---

## Inspiration & Tools

* Datenquelle: [Geoportal Sachsen](https://www.geodaten.sachsen.de/)
* Verwendete Tools: PostgreSQL, PostGIS, GDAL, GNU Parallel, Bash
