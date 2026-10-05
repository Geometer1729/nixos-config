# Fail on failed system or user units; show this boot's errors for review.
status=0
for scope in system user; do
  if ! units=$(systemctl "--$scope" --failed --no-legend --plain); then
    echo "Could not query $scope units" >&2
    status=1
  elif [[ -n $units ]]; then
    echo "Failed $scope units:"
    echo "$units"
    status=1
  else
    echo "No failed $scope units"
  fi
done

echo
echo "Recent boot journal errors (compare with failures.md):"
journalctl -p 3 -b --no-pager -n 10 || echo "No recent critical errors"
exit "$status"
