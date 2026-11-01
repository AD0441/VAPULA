# VAPULA — VAPULA-prueba-visual

Data & Statistical Laboratory · Creado por Sebastián Pastén F.

Project: `8CB60BC3-41BE-4CA8-BF94-9F4E9D9DDA42` · schema 1 · DuckDB 1.1.3 · VAPULA 0.1 development

## Sources

| Source | Bytes | SHA-256 |
|---|---:|---|
| laboratorio.csv | 587 | `1f6cb09dc0d3098cdad6d11e821f73af7c902983d0a03a1698595f9ae6c07169` |

## Dataset versions

- `B2464D87-6040-44DF-AADF-482310C3940F` · laboratorio · 31 rows · source `053F2270-58C4-4654-ABCE-533469C3552B` · parent none · Import
- `F6F471ED-93FB-4A8E-8925-8786645E6CF8` · laboratorio · 16 rows · source `053F2270-58C4-4654-ABCE-533469C3552B` · parent B2464D87-6040-44DF-AADF-482310C3940F · Filter: grupo equal B

## Quality candidates

- Dataset `B2464D87-6040-44DF-AADF-482310C3940F` · Missing / id: 0 affected rows. Candidates for review; a detection does not establish an error.
- Dataset `B2464D87-6040-44DF-AADF-482310C3940F` · Missing / grupo: 0 affected rows. Candidates for review; a detection does not establish an error.
- Dataset `B2464D87-6040-44DF-AADF-482310C3940F` · Missing / x: 1 affected rows. Candidates for review; a detection does not establish an error.
- Dataset `B2464D87-6040-44DF-AADF-482310C3940F` · Missing / y: 1 affected rows. Candidates for review; a detection does not establish an error.
- Dataset `B2464D87-6040-44DF-AADF-482310C3940F` · Missing / categoria: 0 affected rows. Candidates for review; a detection does not establish an error.
- Dataset `B2464D87-6040-44DF-AADF-482310C3940F` · NaN / Inf / id: 0 affected rows. Candidates for review; a detection does not establish an error.
- Dataset `B2464D87-6040-44DF-AADF-482310C3940F` · IQR candidates / id: 0 affected rows. Candidates for review; a detection does not establish an error.
- Dataset `B2464D87-6040-44DF-AADF-482310C3940F` · NaN / Inf / x: 0 affected rows. Candidates for review; a detection does not establish an error.
- Dataset `B2464D87-6040-44DF-AADF-482310C3940F` · IQR candidates / x: 1 affected rows. Candidates for review; a detection does not establish an error.
- Dataset `B2464D87-6040-44DF-AADF-482310C3940F` · NaN / Inf / y: 0 affected rows. Candidates for review; a detection does not establish an error.
- Dataset `B2464D87-6040-44DF-AADF-482310C3940F` · IQR candidates / y: 0 affected rows. Candidates for review; a detection does not establish an error.
- Dataset `B2464D87-6040-44DF-AADF-482310C3940F` · Duplicate candidates / id: 2 affected rows. Candidates for review; a detection does not establish an error.

## Analyses

### t de muestras pareadas

Result `ED9BAA3A-E855-4E1B-AEAD-A576C4A6E359` · dataset `B2464D87-6040-44DF-AADF-482310C3940F` · 2026-10-30T03:25:27Z

Variables: x / y. Valid n=29; excluded=2; alpha=0.05.

Paired t test; H0: mean(X−Y)=0; two-sided Student t, complete finite pairs, alpha=0.05, CI level=0.95. Check normality of differences and independence between units.

| Estadístico | Clave | Valor |
|---|---|---:|
| Límite inferior IC | ci_lower | -20.904157729073408 |
| Límite superior IC | ci_upper | -7.157842270926587 |
| Cohen d_z | cohen_d_z | -0.7765145478428311 |
| Grados de libertad | df | 28.0 |
| Desviación de las diferencias | difference_sd | 18.069204291121554 |
| Diferencia de medias | mean_difference | -14.030999999999997 |
| Media X | mean_x | 21.724137931034484 |
| Media Y | mean_y | 35.755137931034476 |
| Observaciones válidas | n | 29.0 |
| p bilateral | p_two_sided | 0.0002577147471168898 |
| Error estándar | standard_error | 3.355367001430054 |
| Estadístico t | t | -4.1816588152711756 |

- Association does not imply causation. Measurement scale is unspecified; verify its suitability.

