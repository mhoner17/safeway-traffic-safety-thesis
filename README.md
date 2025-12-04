# SafeWay – Location-Based Accident Risk Analysis and Mobile Warning System FOR THESIS

This repository contains the source code and supplementary materials developed for the bachelor thesis:

**Title:** Location-Based Accident Data Analysis and Warning System for Traffic Safety  
**Author:** Muhammed Oner  
**Supervisor:** Prof. Dr. Vitalij Denisov
**Institution:** Klaipeda University  
**Study programme:** JNIN21AK2  

The aim of the thesis is to analyse the spatial and temporal structure of traffic accidents in Lithuania (2020–2024) and to develop a location-based mobile warning system (*SafeWay*) that notifies users when they approach historically dangerous street segments.

---

## Repository structure

- `code/` – Source code for accident data preprocessing, coordinate transformation (LKS94 → WGS84), reverse geocoding, address normalisation, risk-level calculation, and other scripts used to generate the figures and tables in the thesis.  
- `data/` – Example raw and processed datasets, together with data schemas and column descriptions used in the geospatial analysis. (The full official datasets are provided by the Lithuanian Transport Competence Agency (TKA) and are not redistributed here.)  
- `docs/` – Additional documentation and auxiliary files related to the thesis (e.g. figure-related scripts, lists of illustrations, notes).

The exact file names correspond to the scripts and datasets cited in the main text and appendices of the thesis (for example, coordinate conversion scripts, accident-address preparation scripts, and risk-level tables for Kaunas, Vilnius, and Klaipėda).

---

## Data source

All accident data analysed in this thesis originate from the **Lithuanian Transport Competence Agency (TKA)** official open datasets for the years 2020–2024.  
The repository only contains derivative or example files that were created during preprocessing and analysis for academic purposes.I get permissions from them with e-mail.

---

## How to use

1. **Clone or download** this repository:  
   ```bash
   git clone https://github.com/mhoner17/safeway-traffic-safety-thesis
