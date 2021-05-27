# dotfiles

## Checkout

```
git clone --recursive https://github.com/nhalm2/dotfiles.git
```

## Install
```
cd ~/
./dotfiles/initial_setup.sh
```

## Get latest changes
```
git pull origin master
git submodule update --rebase --recursive --remote --init
./initial_setup.sh
```

