# Weekly GTD review
echo "=== GTD WEEKLY REVIEW ==="
echo ""
echo "1. INBOX (should be empty after processing):"
task inbox
echo ""
read -r -p "Press Enter to continue..."

echo ""
echo "2. NEXT ACTIONS (review and update):"
task next
echo ""
read -r -p "Press Enter to continue..."

echo ""
echo "3. WAITING FOR (follow up if needed):"
task waiting
echo ""
read -r -p "Press Enter to continue..."

echo ""
echo "4. PROJECTS (ensure each has a next action):"
task projects
echo ""
read -r -p "Press Enter to continue..."

echo ""
echo "5. SOMEDAY/MAYBE (anything ready to activate?):"
task someday
echo ""
echo "Review complete!"
