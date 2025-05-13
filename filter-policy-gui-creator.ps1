# Define the JSON file path and the output HTML file path
$jsonFilePath = ".\outputs\json\filtering-policies.json"
$htmlFilePath = ".\outputs\html\filter-policy-gui.html"

# Read the JSON file
$jsonData = Get-Content -Path $jsonFilePath -Raw | ConvertFrom-Json


# Start the HTML content
$htmlContent = @"
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Global Secure Access - Security Policy GUI</title>
    <style>
        body {
            font-family: "Segoe UI", Tahoma, Geneva, Verdana, sans-serif;
            background: #f9f9fb;
            margin: 20px;
            color: #333;
        }
        table { 
            width: 100%;
            border-collapse: collapse;
            margin-bottom: 12px;
        }
        th, td { 
            text-align: left;
            padding: 10px; 
        }
        th {
            background: #f1f3f5;
            font-weight: 600;
        }
        tr:nth-child(even) td {
            background-color: #fafafa;
        }
        h1 {
            text-align: center;
            margin-bottom: 20px;
        }
        .expandable { 
            cursor: pointer; 
        }
        .nested-table {
            margin: 12px 0;
            border-left: 4px solid #d1d9e6;
            padding-left: 12px;
            background: #fcfcfe;
            border-radius: 6px;
        }
        .card {
            border-radius: 12px;
            box-shadow: 0 4px 12px rgba(0,0,0,0.05);
            background: white;
            margin-bottom: 24px;
            padding: 16px 24px;
        }
        .profile-header {
            background: #e9f0fb;
            padding: 8px 16px;
            border-radius: 8px;
            font-weight: bold;
            color: #1a4a83;
            margin-top: 12px;
            margin-bottom: 8px;
        }
        .gray-text { color: gray; }
        .icon-allow { 
            color: green; 
            font-weight: bold; 
        }
        .icon-block { 
            color: red; 
            font-weight: bold; 
        }
        .symbol-row { 
            border: 2px solid #1a4a83; 
            padding: 0px 6px 4px 6px; 
            color: #1a4a83; 
            margin-right: 8px; 
            margin-left: -8px; 
        }
    </style>
    <script>
    
        function toggleTable(trId, tableId, symbolId) {
            var row = document.getElementById(trId);
            var table = document.getElementById(tableId);
            var symbol = document.getElementById(symbolId);
            if (table.style.display === "none") {
                table.style.display = "table";
                row.style.display = "";
                symbol.textContent = '-';
            } else {
                table.style.display = "none";
                row.style.display = "none";
                symbol.textContent = '+';
            }
        }


        function sortTable(n) {
            var table, rows, switching, i, x, y, shouldSwitch, dir, switchcount = 0;
            table = document.getElementById("mainTable");
            switching = true;
            dir = "asc"; 
            while (switching) {
                switching = false;
                rows = table.rows;
                for (i = 1; i < (rows.length - 1); i++) {
                    shouldSwitch = false;
                    x = rows[i].getElementsByTagName("TD")[n];
                    y = rows[i + 1].getElementsByTagName("TD")[n];
                    if (dir == "asc") {
                        if (Number(x.innerHTML) > Number(y.innerHTML)) {
                            shouldSwitch = true;
                            break;
                        }
                    } else if (dir == "desc") {
                        if (Number(x.innerHTML) < Number(y.innerHTML)) {
                            shouldSwitch = true;
                            break;
                        }
                    }
                }
                if (shouldSwitch) {
                    rows[i].parentNode.insertBefore(rows[i + 1], rows[i]);
                    switching = true;
                    switchcount++;
                } else {
                    if (switchcount == 0 && dir == "asc") {
                        dir = "desc";
                        switching = true;
                    }
                }
            }
        }
    </script>
</head>
<body>
    <h1>Global Secure Access - Security Policy GUI</h1>
    <div class="card">
"@

# Add the JSON data to the HTML content
foreach ($item in $jsonData) {
    $stateIcon = if ($item.State -eq "enabled") { "<span class='icon-allow'>&#x2714;</span>" } else { "<span class='icon-block'>&#x2716;</span>" }
    $htmlContent += @"
        <div class="profile-header">Profile - '$($item.Name)'</div>
        <table id="mainTable">
            <tr>
                <th onclick="sortTable(0)">Priority</th>
                <th>Name</th>
                <th>Description</th>
                <th>State</th>
                <th>Last Modified</th>
                <th>Created Date</th>
            </tr>
            <tr class="expandable profileTable" onclick="toggleTable('tr_policy_$($item.Id)' ,'table_policy_$($item.Id)', 'symbol-row-$($item.Id)')">
                <td><span class="symbol-row" id="symbol-row-$($item.Id)">-</span> $($item.Priority)</td>
                <td>$($item.Name)</td>
                <td>$($item.Description)</td>
                <td>$stateIcon $($item.State)</td>
                <td>$($item.LastModifiedDateTime)</td>
                <td>$($item.CreatedDateTime)</td>
            </tr>
            <tr id="tr_policy_$($item.Id)" class="profileRow">
                <td colspan="6">
                    <div class="nested-table">
                        <table id="table_policy_$($item.Id)">
                            <tr>
                                <th>Priority</th>
                                <th>Policy Name</th>
                                <th>Policy Description</th>
                                <th>Policy State</th>
                                <th>Action</th>
                                <th>Policy Last Modified</th>
                                <th>Policy Created Date</th>
                            </tr>
"@

    foreach ($policyLink in $item.PolicyLinks) {
        $stateIcon = if ($policyLink.State -eq "enabled") { "<span class='icon-allow'>&#x2714;</span>" } else { "<span class='icon-block'>&#x2716;</span>" }
        $actionIcon = if ($policyLink.Policy.Action -eq "allow") { "<span class='icon-allow'>&#x2714;</span>" } else { "<span class='icon-block'>&#x2716;</span>" }

        $htmlContent += @"
                            <tr class="expandable policyTable" onclick="toggleTable('tr_rule_$($policyLink.Policy.Id)' ,'table_rule_$($policyLink.Policy.Id)', 'symbol-row-$($policyLink.Policy.Id)')">
                                <td><span class="symbol-row" id="symbol-row-$($policyLink.Policy.Id)">-</span> $($policyLink.Priority)</td>
                                <td>$($policyLink.Policy.Name)</td>
                                <td>$($policyLink.Policy.Description)</td>
                                <td>$stateIcon $($policyLink.State)</td>
                                <td>$actionIcon $($policyLink.Policy.Action)</td>
                                <td>$($policyLink.Policy.LastModifiedDateTime)</td>
                                <td>$($policyLink.Policy.CreatedDateTime)</td>
                            </tr>
                            <tr id="tr_rule_$($policyLink.Policy.Id)" class="ruleRow">
                                <td colspan="7">
                                    <div class="nested-table">
                                        <table id="table_rule_$($policyLink.Policy.Id)">
                                            <tr>
                                                <th>Rule Name</th>
                                                <th>Rule Type</th>
                                                <th>Destinations</th>
                                            </tr>
"@

        foreach ($rule in $policyLink.Policy.PolicyRules) {
            $htmlContent += @"
                                            <tr>
                                                <td>$($rule.Name)</td>
                                                <td>$($rule.RuleType)</td>
                                                <td>
"@
            foreach ($destination in $rule.Destinations) {
                if ($rule.RuleType -eq "webCategory") {
                    $htmlContent += @"
                                                    <div>$($destination.displayName) <span class="gray-text">($($destination.group))</span></div>
"@
                } else {
                    $htmlContent += @"
                                                    <div>$($destination.value)</div>
"@
                }
            }
            $htmlContent += @"
                                                </td>
                                            </tr>
"@
        }
        $htmlContent += @"
                                        </table>
                                    </div>
                                </td>
                            </tr>
"@
    }
    $htmlContent += @"
                        </table>
                    </div>
                </td>
            </tr>
        </table>
"@
}

# End the HTML content
$htmlContent += @"
    </div>
</body>
</html>
"@

# Write the HTML content to the output file
$htmlContent | Out-File -FilePath $htmlFilePath -Encoding utf8

Write-Output "HTML file generated at $htmlFilePath"
