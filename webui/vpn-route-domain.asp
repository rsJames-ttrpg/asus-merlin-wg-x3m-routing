<!DOCTYPE html
    PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<html xmlns="http://www.w3.org/1999/xhtml">

<head>
    <meta http-equiv="X-UA-Compatible" content="IE=Edge">
    <meta http-equiv="Content-Type" content="text/html; charset=utf-8" />
    <meta HTTP-EQUIV="Pragma" CONTENT="no-cache">
    <meta HTTP-EQUIV="Expires" CONTENT="-1">
    <link rel="shortcut icon" href="images/favicon.png">
    <link rel="icon" href="images/favicon.png">
    <title>VPN Route Domain</title>
    <link rel="stylesheet" type="text/css" href="index_style.css">
    <link rel="stylesheet" type="text/css" href="form_style.css">
    <script language="JavaScript" type="text/javascript" src="/state.js"></script>
    <script language="JavaScript" type="text/javascript" src="/general.js"></script>
    <script language="JavaScript" type="text/javascript" src="/popup.js"></script>
    <script language="JavaScript" type="text/javascript" src="/help.js"></script>
    <script type="text/javascript" language="JavaScript" src="/validator.js"></script>
    <script>

        var custom_settings = <% get_custom_settings(); %>;

        function initial() {
            SetCurrentPage();
            show_menu();
            loadSettings();
        }

        function SetCurrentPage() {
            document.form.next_page.value = window.location.pathname.substring(1);
            document.form.current_page.value = window.location.pathname.substring(1);
        }

        function loadSettings() {
            // Load saved settings or defaults
            document.getElementById('vpn_rd_ipset').value =
                custom_settings.vpn_rd_ipset || 'vpn_domains';
            document.getElementById('vpn_rd_table').value =
                custom_settings.vpn_rd_table || 'wgc1';
            document.getElementById('vpn_rd_domains').value =
                custom_settings.vpn_rd_domains || '';
        }

        function addDomain() {
            var newDomain = document.getElementById('new_domain').value.trim();
            if (newDomain === '') {
                alert('Please enter a domain name');
                return;
            }

            var currentDomains = document.getElementById('vpn_rd_domains').value;
            if (currentDomains === '') {
                document.getElementById('vpn_rd_domains').value = newDomain;
            } else {
                // Check if domain already exists
                var domainList = currentDomains.split('\n');
                if (domainList.indexOf(newDomain) !== -1) {
                    alert('Domain already in list');
                    return;
                }
                document.getElementById('vpn_rd_domains').value = currentDomains + '\n' + newDomain;
            }
            document.getElementById('new_domain').value = '';
        }

        function removeDomain() {
            var textarea = document.getElementById('vpn_rd_domains');
            var domains = textarea.value.split('\n');
            var selected = textarea.value.substring(
                textarea.selectionStart,
                textarea.selectionEnd
            ).trim();

            if (selected === '') {
                alert('Select a domain in the list to remove');
                return;
            }

            var newDomains = domains.filter(function (d) {
                return d.trim() !== selected;
            });
            textarea.value = newDomains.join('\n');
        }

        function applySettings() {
            // Store settings in object
            custom_settings.vpn_rd_ipset = document.getElementById('vpn_rd_ipset').value;
            custom_settings.vpn_rd_table = document.getElementById('vpn_rd_table').value;
            custom_settings.vpn_rd_domains = document.getElementById('vpn_rd_domains').value;

            // Store object as string in hidden field
            document.getElementById('amng_custom').value = JSON.stringify(custom_settings);

            // Apply
            showLoading();
            document.form.submit();
        }

    </script>
</head>

<body onload="initial();" class="bg">
    <div id="TopBanner"></div>
    <div id="Loading" class="popup_bg"></div>
    <iframe name="hidden_frame" id="hidden_frame" src="" width="0" height="0" frameborder="0"></iframe>

    <form method="post" name="form" action="start_apply.htm" target="hidden_frame">
        <input type="hidden" name="current_page" value="">
        <input type="hidden" name="next_page" value="">
        <input type="hidden" name="group_id" value="">
        <input type="hidden" name="modified" value="0">
        <input type="hidden" name="action_mode" value="apply">
        <input type="hidden" name="action_wait" value="5">
        <input type="hidden" name="action_script" value="restart_vpnroutedomain">
        <input type="hidden" name="first_time" value="">
        <input type="hidden" name="preferred_lang" id="preferred_lang" value="<% nvram_get(" preferred_lang"); %>">
        <input type="hidden" name="firmver" value="<% nvram_get(" firmver"); %>">
        <input type="hidden" name="amng_custom" id="amng_custom" value="">

        <table class="content" align="center" cellpadding="0" cellspacing="0">
            <tr>
                <td width="17">&nbsp;</td>
                <td valign="top" width="202">
                    <div id="mainMenu"></div>
                    <div id="subMenu"></div>
                </td>
                <td valign="top">
                    <div id="tabMenu" class="submenuBlock"></div>
                    <table width="98%" border="0" align="left" cellpadding="0" cellspacing="0">
                        <tr>
                            <td align="left" valign="top">
                                <table width="760px" border="0" cellpadding="5" cellspacing="0" bordercolor="#6b8fa3"
                                    class="FormTitle" id="FormTitle">
                                    <tr>
                                        <td bgcolor="#4D595D" colspan="3" valign="top">
                                            <div>&nbsp;</div>
                                            <div class="formfonttitle">VPN Route Domain</div>
                                            <div style="margin:10px 0 10px 5px;" class="splitLine"></div>
                                            <div class="formfontdesc">Route specific domains through your WireGuard VPN.
                                            </div>

                                            <table width="100%" border="1" align="center" cellpadding="4"
                                                cellspacing="0" bordercolor="#6b8fa3" class="FormTable">
                                                <thead>
                                                    <tr>
                                                        <td colspan="2">Configuration</td>
                                                    </tr>
                                                </thead>
                                                <tr>
                                                    <th width="30%">IPSET Name</th>
                                                    <td>
                                                        <input type="text" maxlength="30" class="input_15_table"
                                                            id="vpn_rd_ipset" value="vpn_domains" autocorrect="off"
                                                            autocapitalize="off">
                                                    </td>
                                                </tr>
                                                <tr>
                                                    <th>WireGuard Table</th>
                                                    <td>
                                                        <select id="vpn_rd_table" class="input_option">
                                                            <option value="wgc1">WireGuard Client 1 (wgc1)</option>
                                                            <option value="wgc2">WireGuard Client 2 (wgc2)</option>
                                                            <option value="wgc3">WireGuard Client 3 (wgc3)</option>
                                                            <option value="wgc4">WireGuard Client 4 (wgc4)</option>
                                                            <option value="wgc5">WireGuard Client 5 (wgc5)</option>
                                                        </select>
                                                    </td>
                                                </tr>
                                            </table>

                                            <table width="100%" border="1" align="center" cellpadding="4"
                                                cellspacing="0" bordercolor="#6b8fa3" class="FormTable"
                                                style="margin-top:15px;">
                                                <thead>
                                                    <tr>
                                                        <td colspan="2">Domains</td>
                                                    </tr>
                                                </thead>
                                                <tr>
                                                    <th width="30%">Add Domain</th>
                                                    <td>
                                                        <input type="text" maxlength="100" class="input_25_table"
                                                            id="new_domain" placeholder="example.com" autocorrect="off"
                                                            autocapitalize="off">
                                                        <input type="button" class="button_gen" onclick="addDomain();"
                                                            value="Add">
                                                    </td>
                                                </tr>
                                                <tr>
                                                    <th>Domain List<br><span
                                                            style="font-weight:normal;font-size:11px;">(select to
                                                            remove)</span></th>
                                                    <td>
                                                        <textarea id="vpn_rd_domains" rows="10" class="input_32_table"
                                                            style="width:95%; font-family:monospace;"
                                                            readonly></textarea>
                                                        <br>
                                                        <input type="button" class="button_gen"
                                                            onclick="removeDomain();" value="Remove Selected">
                                                    </td>
                                                </tr>
                                            </table>

                                            <div class="apply_gen">
                                                <input name="button" type="button" class="button_gen"
                                                    onclick="applySettings();" value="Apply" />
                                            </div>

                                        </td>
                                    </tr>
                                </table>
                            </td>
                        </tr>
                    </table>
                </td>
                <td width="10" align="center" valign="top"></td>
            </tr>
        </table>
    </form>
    <div id="footer"></div>
</body>

</html>