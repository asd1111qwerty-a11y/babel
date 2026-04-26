function loadFooter(containerId) {
    const loggedUser = localStorage.getItem('loggedUser');
    const token = localStorage.getItem('token');
    const footerEl = document.getElementById(containerId);
    if (!footerEl) return;

    function renderFooter(guildLink) {
        const dropId = 'communityDropdown_' + containerId;
        const btnId = 'communityBtn_' + containerId;

        footerEl.innerHTML = `
            <span class="text-muted">
                <a href="index.html">Home</a> | 
                <a href="${loggedUser ? 'account.html' : 'login.html'}">${loggedUser ? 'Account' : 'Login'}</a> | 
                <span style="position:relative; display:inline-block;">
                    <a href="#" id="${btnId}" onclick="toggleCommunity(event, '${dropId}', '${btnId}')">Community</a>
                    <div id="${dropId}" style="display:none; position:absolute; bottom:24px; left:50%; transform:translateX(-50%); background:#fff; border:1px solid #ddd; border-radius:6px; box-shadow:0 2px 8px rgba(0,0,0,0.15); min-width:130px; z-index:999; text-align:center;">
                        <a href="notifications.html" style="display:block; padding:8px 16px; color:#333; text-decoration:none; border-bottom:1px solid #eee;">Notifications</a>
                        <a href="highscore.html" style="display:block; padding:8px 16px; color:#333; text-decoration:none; border-bottom:1px solid #eee;">Highscore</a>
                        <a href="guilds.html" style="display:block; padding:8px 16px; color:#333; text-decoration:none; ${guildLink ? 'border-bottom:1px solid #eee;' : ''}">Guilds</a>
                        ${guildLink ? `<a href="${guildLink.url}" style="display:block; padding:8px 16px; color:#000000; text-decoration:none; font-weight:bold;">${guildLink.prefix}</a>` : ''}
                    </div>
                </span> | 
                <a href="#">Contact</a>
            </span>
        `;
    }

    // Kalau user login, fetch data guild
    if (loggedUser && token) {
        fetch('http://203.175.125.153/profile', {
            headers: { 'Authorization': token }
        })
            .then(r => r.json())
            .then(data => {
                if (data.success && data.user && data.user.guild_id) {
                    fetch('http://203.175.125.153/guild/' + data.user.guild_id)
                        .then(r => r.json())
                        .then(gData => {
                            if (gData.success && gData.guild) {
                                renderFooter({
                                    url: 'guild.html?id=' + data.user.guild_id,
                                    prefix: '' + gData.guild.tag + ''
                                });
                            } else {
                                renderFooter(null);
                            }
                        });
                } else {
                    renderFooter(null);
                }
            })
            .catch(() => renderFooter(null));
    } else {
        renderFooter(null);
    }
}

function toggleCommunity(e, dropId, btnId) {
    e.preventDefault();
    var d = document.getElementById(dropId);
    d.style.display = d.style.display === 'none' ? 'block' : 'none';
    setTimeout(function () {
        document.addEventListener('click', function handler(ev) {
            if (!ev.target.closest('#' + dropId) && ev.target.id !== btnId) {
                d.style.display = 'none';
            }
            document.removeEventListener('click', handler);
        });
    }, 0);
}