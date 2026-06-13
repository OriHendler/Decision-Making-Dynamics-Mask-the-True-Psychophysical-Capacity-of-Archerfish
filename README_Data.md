# Data: Fish\_Data\_Updated\_with\_2ACT2P\_V2.xlsx

This workbook holds the trial-by-trial behavioral data for the archerfish learning
study. Structure:

* One sheet per fish, named `1` through `14`.
* One row per trial, with a header row on top.



### Fish groups and tasks

|Sheets|Group|Task|Positions used|
|-|-|-|-|
|1 to 5|2ACT2P|two-position choice|3 and 4|
|6 to 11|shape|shape discrimination, four quadrants|1 to 4|
|12 to 14|abstract shape|abstract shape discrimination, four quadrants|1 to 4|

In the two-position task the two stimuli appear at positions 3 and 4. In the
four-quadrant tasks they appear at any two of quadrants 1 to 4.

## Columns

Each sheet has the following columns, left to right.

|Column|Type|Meaning|
|-|-|-|
|slide|integer|trial index within the sheet|
|results|see below|trial outcome|
|relevance|text|trial inclusion flag (`Y`)|
|Session type|text|`Reinforcement` or `Probe`. May be blank on some trials.|
|Block name|text|session or block identifier|
|non\_target|integer|position of the non-target stimulus on that trial|
|target|integer|position of the target, that is the rewarded, stimulus on that trial|
|recording|text|recording identifier|

A few sheets carry extra helper columns to the right of `recording` (for example
an `Analysis` column). These are not read by any script and can be ignored.

### 

### The `results` column

This is the trial outcome.

* `1` means the fish chose the target (correct).
* `0` means the fish chose the non-target (incorrect).
* Any other entry, including blanks, `NAN`, and single-letter codes such as `M`,
`S`, `A`, `C`, or `O`, marks a non-response or an excluded trial.

### 

### The `target` and `non\_target` columns

These give the on-screen position of each stimulus on that trial, as a quadrant
number. `target` is the position of the rewarded stimulus and `non\_target` is the
position of the other stimulus. The target stimulus is fixed for a given fish, but
its position is varied from trial to trial, so these two columns change row by row.
Accuracy is defined relative to the target: `results = 1` means the fish went to the
position held by the target on that trial.

### 

### The `Session type` column

`Reinforcement` trials are rewarded. `Probe` trials are the unrewarded probe trials
used in the probe-versus-reinforced comparison. Some trials have no session label and
count toward the accuracy and model analyses but not toward the probe-versus-reinforced
comparison. Fish 6 has only reinforcement trials, so it is excluded from that
comparison, which leaves 13 fish.

## 

## Per-fish summary

Counts below are over responded trials (`results` equal to `0` or `1`).

|Fish|Group|Responded|Correct|Accuracy|Reinforcement|Probe|Unlabeled|Positions|
|-|-|-|-|-|-|-|-|-|
|1|2ACT2P|509|349|0.69|152|357|0|3, 4|
|2|2ACT2P|588|433|0.74|167|421|0|3, 4|
|3|2ACT2P|599|457|0.76|172|427|0|3, 4|
|4|2ACT2P|578|342|0.59|27|51|500|3, 4|
|5|2ACT2P|589|497|0.84|141|448|0|3, 4|
|6|shape|366|273|0.75|366|0|0|1 to 4|
|7|shape|536|396|0.74|169|367|0|1 to 4|
|8|shape|585|355|0.61|160|385|40|1 to 4|
|9|shape|325|243|0.75|118|207|0|1 to 4|
|10|shape|492|395|0.80|201|291|0|1 to 4|
|11|shape|510|399|0.78|106|404|0|1 to 4|
|12|abstract shape|400|274|0.69|108|292|0|1 to 4|
|13|abstract shape|629|390|0.62|213|416|0|1 to 4|
|14|abstract shape|304|155|0.51|114|190|0|1 to 4|

Fish 4 has many trials with no session label, so it contributes only 27 reinforcement
and 51 probe trials to the probe-versus-reinforced comparison while still contributing
all 578 responded trials to the accuracy and model analyses.

## 

