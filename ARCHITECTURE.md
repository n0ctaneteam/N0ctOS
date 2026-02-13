# Wanna know how things work ?
## Branch Struct:
### main: active branch
mereged from development branch, only after it is a lil stable. Kind of works like a checkpoint.

### development: active \*development\* branch
add features here.. Break, fix, add, remove.. all things here.
It only gets merged with **main** in these cases:
- a fix is published
- a feature is finalized (add or remove, mostly add. cz why will u remove it bruh)
- or anything changes, but still stable

### lts: more stable than **main**. kinda like beta testing version
it is pulled from **main**, when:
- multiple features are added,
- many stuff changed,
- many fixes are done,
need testing...
LTS branch is more likely to be a QA & Tester branch. But can give stability for daily use... Early access stuff yk.

### stable: the most stable branch, this is what we call update, this is what we ship through ISO
it is pulled from **lts** after done QA & Testing and fixing any bugs...
this is the final product that ships to end-user

### Stability order:
Stable > Lts > main > development
