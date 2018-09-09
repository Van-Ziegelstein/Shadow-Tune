@echo off
cd ..

if not exist shadow_tune.pl (
   
   echo shadow_tune.pl not found!
   goto :linger
)

>NUL 2>&1 where perl || (

   echo No Perl interpreter found!
   goto :linger
)

echo Starting Shadow Tune...
perl shadow_tune.pl
goto :end

:linger
echo.
echo Press any key to exit...
>NUL timeout 5

:end
