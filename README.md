# Decision-Making Dynamics Mask the True Psychophysical Capacity of Archerfish

This repository contains the data and MATLAB code to reproduce the figures in the study. 

All analyses run from a single data workbook.



## Repository layout

```
.
├── README.md
├── code/                                   MATLAB scripts
│   ├── ACCURACY\\\\\\\_analysis\\\\\\\_single\\\\\\\_excelV5.m  Figure 1
│   ├── DynamicGLM\\\\\\\_Hendler\\\\\\\_2pos\\\\\\\_7models.m   Figure 2 (fish 1-5)
│   ├── DynamicGLM\\\\\\\_Hendler\\\\\\\_4quad\\\\\\\_5models.m  Figure 3 (fish 6-14)
│   ├── DynamicGLM\\\\\\\_Hendler\\\\\\\_plot\\\\\\\_results.m   per-fish model plots + Figure 4 model comparison
│   ├── ProbeVsReinforcement\\\\\\\_Figure4.m      Figure 4 probe vs reinforced scatter
│   └── FISH\\\\\\\_TRIAL\\\\\\\_DETAILS.m                per-fish trial-count table (supplementary)
├── data/
│   └── Fish\\\\\\\_Data\\\\\\\_Updated\\\\\\\_with\\\\\\\_2ACT2P\\\\\\\_V2.xlsx
└── output/                                 created on first run
    ├── FIGURE 1/
    ├── FIGURE 2/
    ├── FIGURE 3/
    └── FIGURE 4/
```

Keep the three folders side by side. Each script finds the workbook in `../data`
and writes its results into `../output`.



## How to run

Run the scripts from the `code` folder in this order. Steps 2 and 3 must precede
step 4, because the plotting script reads the per-fish model files they produce.



1. `ACCURACY\\\\\\\_analysis\\\\\\\_single\\\\\\\_excelV5.m` writes the per-fish accuracy bar plots to
`output/FIGURE 1`.

2. `DynamicGLM\\\\\\\_Hendler\\\\\\\_2pos\\\\\\\_7models.m` fits the 2-position task (fish 1 to 5) and
writes per-fish model files to `output/FIGURE 2`.

3. `DynamicGLM\\\\\\\_Hendler\\\\\\\_4quad\\\\\\\_5models.m` fits the 4-quadrant task (fish 6 to 14) and
writes per-fish model files to `output/FIGURE 3`.

4. `DynamicGLM\\\\\\\_Hendler\\\\\\\_plot\\\\\\\_results.m` draws the per-fish model plots and the
model comparison. Run it twice:

   * `FIGURE\\\\\\\_NUM = 2`, `FISH\\\\\\\_LIST = 1:5` for the 2-position fish.
   * `FIGURE\\\\\\\_NUM = 3`, `FISH\\\\\\\_LIST = 6:14` for the 4-quadrant fish.
The cross-fish model comparison is written to `output/FIGURE 4`.



5. `ProbeVsReinforcement\\\\\\\_Figure4.m` writes the probe vs reinforced accuracy scatter
to `output/FIGURE 4`.

`FISH\\\\\\\_TRIAL\\\\\\\_DETAILS.m` reports per-fish trial counts and can be run at any time.
It prints to the console and, if `SAVE\\\\\\\_TABLE = true`, writes a table to `output`.



### Figure to script map



|Figure|Script|Output|
|-|-|-|
|1|ACCURACY\_analysis\_single\_excelV5.m|output/FIGURE 1|
|2|DynamicGLM\_Hendler\_2pos\_7models.m, then DynamicGLM\_Hendler\_plot\_results.m (FIGURE\_NUM = 2)|output/FIGURE 2|
|3|DynamicGLM\_Hendler\_4quad\_5models.m, then DynamicGLM\_Hendler\_plot\_results.m (FIGURE\_NUM = 3)|output/FIGURE 3|
|4|DynamicGLM\_Hendler\_plot\_results.m (model comparison) and ProbeVsReinforcement\_Figure4.m (probe vs reinforced scatter)|output/FIGURE 4|

## 

## Data

`Fish\\\\\\\_Data\\\\\\\_Updated\\\\\\\_with\\\\\\\_2ACT2P\\\\\\\_V2.xlsx` has one sheet per fish, named `1` through
`14`. Each row is a trial. Columns:



|Column|Meaning|
|-|-|
|slide|trial index within the sheet|
|results|trial outcome. `1` = chose the target (correct), `0` = chose the non-target (incorrect). Non-numeric entries (blank, `NAN`, or letter codes such as `M`, `S`, `A`, `C`) mark non-response or excluded trials and are dropped by every analysis.|
|relevance|trial inclusion flag|
|Session type|`Reinforcement` or `Probe`|
|Block name|session or block identifier|
|non\_target|position of the non-target stimulus on that trial (quadrant 1 to 4, or position 3/4 in the 2-position task)|
|target|position of the target, that is rewarded, stimulus on that trial|
|recording|recording identifier|



The model scripts read `results`, `target`, and `non\\\\\\\_target`. The accuracy and
trial-count scripts read `results`. The probe versus reinforced scatter reads
`results` and `Session type`.

Fish groups:

* Fish 1 to 5: two-position (2ACT2P) task, analyzed with the 7-model script.
* Fish 6 to 11: shape discrimination task, analyzed with the 5-model script.
* Fish 12 to 14: abstract shape task, analyzed with the 5-model script.

In the probe versus reinforced analysis, fish 6 has no probe trials and is
therefore excluded, leaving 13 fish. The shaded band in that figure marks the
+/- 0.15 equivalence bound used in the equivalence test.



## Requirements

* MATLAB, tested with R2021a and later. `exportgraphics` requires R2020a or later.
* The scripts use base MATLAB functions (`readcell`, `readtable`, `bar`,
`errorbar`, `scatter`, `exportgraphics`). The model fitting is self-contained.
If MATLAB reports a missing function, the most likely dependency is the
Statistics and Machine Learning Toolbox.

No internet connection is required. Figures are written in `.fig`, `.jpg`, `.tif`,
and `.pdf` at 600 dpi.



## License

Data license CC-BY-4.0.



## How to cite

Cite associated paper please. 

## 

## Contact

hendlero@post.bgu.ac.il

ori.hendler21@gmail.com



Ori Hendler.

Ben Gurion University of the Negev, Beer Sheba, Israel.

