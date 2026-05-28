# Wanna know how things work ?
## Branch Struct:
### development: active \*development\* branch
add features here.. Break, fix, add, remove.. all things here.
- a fix is published
- a feature is finalized (add or remove, mostly add. cz why will u remove it bruh)
- or anything changes, but still stable

### stable: the more stable branch, this is what we call update
it is pulled from **development** after done QA & Testing and fixing any bugs...
this is the final product that ships to end-user

### lts: most stable version, this is what we ship through ISO
it is pulled from **stable**:
- multiple features are added,
- many stuff changed,
- many fixes are done,
need testing...
LTS branch is more likely to be major release branch, e.g. 3.X.X... ISO will be Rebuilt automatically when this updates.

### Stability order:
Lts > Stable > development

 - STABLE branch will be the default branch on client installed system
 - LTS will be the main branch for ISOs, ISO pull this and build themselves using this config... later after installation, check for updates and update