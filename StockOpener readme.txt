Readme

command to make changes (need to re compile exe after for icon)

cd $HOME\Documents\StockOpener
.\StockOpenerGUI.ps1

recompile command:

Invoke-ps2exe -inputFile ".\StockOpenerGUI.ps1" -outputFile "$env:LOCALAPPDATA\Programs\StockOpener\StockOpener.exe" -iconFile ".\icon.ico" -noConsole


and i think after you put that then:

next fix i want is when you stack up two windows and close them out, the firefox window you had up before it should take up focus

setup git repository for branch