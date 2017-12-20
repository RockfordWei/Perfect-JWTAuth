clear
echo "---- M A C O S ----"
rm -rf /tmp/users /tmp/users.db
swift test
echo "---- L I N U X ----"
docker run -it -v /Users/rockywei/Documents/PerfectSSOAuth:/home -v /private/var:/private/var -e URL_PERFECT=/private/var/perfect -w /home rockywei/swift:4.0 /bin/bash -c "swift test"
