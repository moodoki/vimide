#!/bin/bash

venvname=${1:-mlenv}
other_args=${@:2}

echo python3 -m venv ~/.venvs/${venvname} ${other_args}
python3 -m venv ~/.venvs/${venvname} ${other_args}
source ~/.venvs/${venvname}/bin/activate

pip install --upgrade pip
pip install --upgrade setuptools
pip install --upgrade wheel
pip install matplotlib
pip install jupyter
pip install jupyterlab
pip install numpy scipy
pip install tensorflow
pip install tensorflow-addons
pip install torch torchvision
pip install seaborn bokeh
pip install pillow
pip install scikit-image scikit-video
pip install opencv-python
pip install opencv-contrib-python
pip install tqdm

jupyter nbextension enable --py widgetsnbextension
jupyter labextension install @jupyter-widgets/jupyterlab-manager
