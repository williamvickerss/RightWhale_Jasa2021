# JASA 2021 Machine Learning Special Edition
>Paper - Robust North Atlantic Right Whale Detection using Deep Learning Models for Denoising   
>Authors - W.Vickers, B.Milner, D.Risch, R.Lee
## Data Setup
This repository contains two files to download, extract and partition the DCLDE 2013 Right Whale Dataset into the same experimental split used in the above paper.   

### Getting Started
1. Run the Matlab file ```setup.m```. This script will automatically download and extract all the relevant files from the DCLDE 2013 competition. Files will be stored within the folder ```DCLDE2013_Data``` at the same location as where the script is run from. 
2. ```Requirements.txt``` has been supplied to provided up-to-date python dependencies. It is recommended you install these before continuing.
3. Run the Python file ```partition.py```. Only run this script after step 1. This script will partition the data into the same train, validation and test splits used in the above paper. A standard clean partition will be produced if no flags are used. Options below give the ability to create noisy partitions.</br></br>


> #### ```partition.py```
> ##### Script Options
> * `-w` - This will produce a version of the partition with white noise added at set signal-to-nosie ratios of [5, 0, -5, -10]. Will also produce the standard variant unless `-m` is used.
> * `-m` - Will turn off the standard partition and only produce a noise variant if selected.
