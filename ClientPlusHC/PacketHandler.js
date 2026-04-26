var Packet = require('./packet');
var Commands = require('./modules/CommandList');
var fs = require('fs');   // ← TAMBAH
var http = require('http');
var LastMsg;
var SpamBlock;

function PacketHandler(gameServer, socket) {
    this.gameServer = gameServer;
    this.socket = socket;
    this.protocol = 0;
    this.pressQ = false;
    this.pressW = false;
    this.pressSpace = false;
}

module.exports = PacketHandler;

PacketHandler.prototype.handleMessage = function (message) {
    function stobuf(buf) {
        var length = buf.length;
        var arrayBuf = new ArrayBuffer(length);
        var view = new Uint8Array(arrayBuf);
        for (var i = 0; i < length; i++) {
            view[i] = buf[i];
        }
        return view.buffer;
    }

    if (message.length == 0) return;

    var buffer = stobuf(message);
    var view = new DataView(buffer);
    var packetId = view.getUint8(0, true);

    switch (packetId) {
        case 0:
            var skin = "";
            var nick = "";
            var i = 1;

            if (i < view.byteLength && view.getUint8(i) === 37) {
                i++;
                while (i < view.byteLength) {
                    var b = view.getUint8(i);
                    i++;
                    if (b === 0) break;
                    skin += String.fromCharCode(b);
                }
            }

            var maxLen = 60 * 2;
            var nickStart = i;
            while (i < view.byteLength && i <= nickStart + maxLen) {
                var charCode = view.getUint16(i, true);
                i += 2;
                if (charCode === 0) break;
                nick += String.fromCharCode(charCode);
            }

            this.socket.playerTracker.skin = skin;
            this.setNickname(nick, skin);
            break;

        case 1:
            if (this.socket.playerTracker.cells.length <= 0) {
                this.gameServer.switchSpectator(this.socket.playerTracker);
                this.socket.playerTracker.spectate = true;
            }
            break;

        case 2:
            var nickOnly = "";
            var iN = 1;
            while (iN < view.byteLength) {
                var charCode = view.getUint16(iN, true);
                iN += 2;
                if (charCode === 0) break;
                nickOnly += String.fromCharCode(charCode);
            }
            if (nickOnly) {
                var nickSet = nickOnly;
                var colorSet = null;
                if (nickSet.indexOf('|') !== -1) {
                    var parts = nickSet.split('|');
                    var maybeColor = parts[0];
                    if (maybeColor.charAt(0) === '#' && maybeColor.length === 7) {
                        colorSet = maybeColor;
                        nickSet = parts.slice(1).join('|');
                    }
                }

                var cleanNick = nickSet;
                if (cleanNick.indexOf('] ') !== -1) cleanNick = cleanNick.split('] ')[1] || cleanNick;

                // ✅ FIX: pakai cache, bukan HTTP langsung
                (function (socket, nick, fullNick, color) {
                    socket.playerTracker.gameServer.getCachedRole(nick, function (rd) {
                        var finalNick = fullNick;
                        try {
                            var roles = rd.roles || [rd.role];
                            if (roles.includes('noname')) finalNick = '\x04' + fullNick;
                        } catch (e) { }
                        socket.playerTracker.setName(finalNick);
                        if (color) {
                            var r = parseInt(color.slice(1, 3), 16);
                            var g = parseInt(color.slice(3, 5), 16);
                            var b = parseInt(color.slice(5, 7), 16);
                            socket.playerTracker.color = { r: r, g: g, b: b };
                        }
                    });
                })(this.socket, cleanNick, nickSet, colorSet);
            }
            break;

        case 16:
            var client = this.socket.playerTracker;
            if (view.byteLength == 13) {
                client.mouse.x = view.getInt32(1, true);
                client.mouse.y = view.getInt32(5, true);
            } else if (view.byteLength == 9) {
                client.mouse.x = view.getInt16(1, true);
                client.mouse.y = view.getInt16(3, true);
            } else if (view.byteLength == 21) {
                client.mouse.x = view.getFloat64(1, true);
                client.mouse.y = view.getFloat64(9, true);
            }
            break;

        case 17:
            this.pressSpace = true;
            break;
        case 18:
            this.pressQ = true;
            break;
        case 19:
            break;
        case 21:
            this.pressW = true;
            break;

        case 80:
            var yada = "";
            for (var i = 1; i < view.byteLength; i++) {
                yada += String.fromCharCode(view.getUint8(i, true));
            }
        case 90:
            var player = 0;
            var client;
            for (var i = 0; i < this.gameServer.clients.length; i++) {
                client = this.gameServer.clients[i].playerTracker;
                if ((client.disconnect <= 0) && (client.spectate == false)) ++player;
            }
            this.socket.sendPacket(new Packet.ServerInfo(process.uptime().toFixed(0), player, this.gameServer.config.borderRight, this.gameServer.config.foodMaxAmount, this.gameServer.config.serverGamemode));
            break;

        case 255:
            if (view.byteLength == 5) {
                var c = this.gameServer.config, player = 0, client;
                for (var i = 0; i < this.gameServer.clients.length; i++) {
                    client = this.gameServer.clients[i].playerTracker;
                    if ((client.disconnect <= 0) && (client.spectate == false)) ++player;
                }
                if (player > c.serverMaxConnections) {
                    this.socket.sendPacket(new Packet.ServerMsg(93));
                    this.socket.close();
                }
                this.socket.sendPacket(new Packet.SetBorder(c.borderLeft, c.borderRight, c.borderTop, c.borderBottom));
                this.socket.sendPacket(new Packet.ServerInfo(process.uptime().toFixed(0), player, c.borderRight, c.foodMaxAmount, this.gameServer.config.serverGamemode));
                break;
            }
            break;

        case 99:
            var message = "",
                maxLen = this.gameServer.config.chatMaxMessageLength * 2,
                offset = 2,
                flags = view.getUint8(1);

            if (flags & 2) { offset += 4; }
            if (flags & 4) { offset += 8; }
            if (flags & 8) { offset += 16; }

            for (var i = offset; i < view.byteLength && i <= maxLen; i += 2) {
                var charCode = view.getUint16(i, true);
                if (charCode == 0) break;
                message += String.fromCharCode(charCode);
            }

            var date = new Date();
            if ((date - this.socket.playerTracker.cTime) < 500) break;
            this.socket.playerTracker.cTime = date;

            var rawName = this.socket.playerTracker.name || '';
            var wname = rawName.indexOf('\n') !== -1 ? rawName.split('\n')[1] : rawName;
            var zname = wname;
            if (wname == "") wname = "Spectator";

            // Mute check
            var muteCheckName = wname;
            if (muteCheckName.indexOf('] ') !== -1) muteCheckName = muteCheckName.split('] ')[1] || muteCheckName;
            muteCheckName = muteCheckName.replace(/^[\x01\x02\x03\x04]/, '');
            if (this.gameServer.muted && this.gameServer.muted.indexOf(muteCheckName.toLowerCase()) !== -1) {
                var muteNotif = '\u274C You are muted and cannot send messages.';
                var muteNick = '[SERVER]';
                var muteBuf = new ArrayBuffer(9 + 2 * muteNick.length + 2 * muteNotif.length);
                var muteView = new DataView(muteBuf);
                muteView.setUint8(0, 99); muteView.setUint8(1, 0);
                muteView.setUint8(2, 255); muteView.setUint8(3, 80); muteView.setUint8(4, 80);
                var muteOffset = 5;
                for (var mi = 0; mi < muteNick.length; mi++) { muteView.setUint16(muteOffset, muteNick.charCodeAt(mi), true); muteOffset += 2; }
                muteView.setUint16(muteOffset, 0, true); muteOffset += 2;
                for (var mi = 0; mi < muteNotif.length; mi++) { muteView.setUint16(muteOffset, muteNotif.charCodeAt(mi), true); muteOffset += 2; }
                muteView.setUint16(muteOffset, 0, true);
                try { this.socket.send(muteBuf); } catch (e) { }
                break;
            }

            // rcon
            if (this.gameServer.config.serverAdminPass != '') {
                var passkey = "/rcon " + this.gameServer.config.serverAdminPass + " ";
                if (message.substr(0, passkey.length) == passkey) {
                    var cmd = message.substr(passkey.length, message.length);
                    console.log("\u001B[36m" + wname + ": \u001B[0missued a remote console command: " + cmd);
                    var split = cmd.split(" "), first = split[0].toLowerCase(), execute = this.gameServer.commands[first];
                    if (typeof execute != 'undefined') execute(this.gameServer, split);
                    else console.log("Invalid Command!");
                    break;
                } else if (message.substr(0, 6) == "/rcon ") {
                    console.log("\u001B[36m" + wname + ": \u001B[0missued a remote console command but used a wrong pass key!");
                    break;
                }
            }

            // ✅ FIX: Admin command - pakai cache
            if (message.charAt(0) === '/' && message.substr(0, 6) !== '/rcon ' && message.substr(0, 3).toLowerCase() !== '/g ' && message.toLowerCase() !== '/g') {
                var self = this;
                var adminName = wname.replace(/^[\x00-\x05]/, "");
                if (adminName.indexOf('] ') !== -1) adminName = adminName.split('] ')[1] || adminName;

                self.gameServer.getCachedRole(adminName, function (data) {
                    try {
                        function sendServerMsg(name, r, g, b, msg) {
                            var nick = name;
                            var buf = new ArrayBuffer(9 + 2 * nick.length + 2 * msg.length);
                            var view = new DataView(buf);
                            view.setUint8(0, 99); view.setUint8(1, 0);
                            view.setUint8(2, r); view.setUint8(3, g); view.setUint8(4, b);
                            var offset = 5;
                            for (var j = 0; j < nick.length; j++) { view.setUint16(offset, nick.charCodeAt(j), true); offset += 2; }
                            view.setUint16(offset, 0, true); offset += 2;
                            for (var j = 0; j < msg.length; j++) { view.setUint16(offset, msg.charCodeAt(j), true); offset += 2; }
                            view.setUint16(offset, 0, true);
                            self.socket.send(buf);
                        }

                        if (data.role === 'admin') {
                            var cmd = message.substr(1);
                            console.log('\u001B[33m[ADMIN] ' + adminName + ' executed: /' + cmd + '\u001B[0m');

                            if (cmd.toLowerCase() === 'help') {
                                var helpLines = ['killall | kill | mass | tp | kick', 'ban | unban | say | name | color', 'food | virus | split | merge | pause', 'status | playerlist | reload | addbot'];
                                helpLines.forEach(function (line) { sendServerMsg('[ADMIN]', 255, 200, 0, line); });
                                return;
                            }

                            var split = cmd.split(' ');
                            var first = split[0].toLowerCase();
                            var execute = self.gameServer.commands[first];
                            if (first === 'merge' && split.length === 1) split.push(adminName);
                            if (first === 'mass' && split.length === 2 && !isNaN(parseInt(split[1]))) split = ['mass', adminName, split[1]];

                            if (typeof execute != 'undefined') {
                                var outputLines = [];
                                var originalLog = console.log;
                                console.log = function () {
                                    var line = Array.prototype.slice.call(arguments).join(' ');
                                    originalLog(line);
                                    outputLines.push(line);
                                };
                                execute(self.gameServer, split);
                                setTimeout(function () {
                                    console.log = originalLog;
                                    function stripAnsi(str) { return str.replace(/\u001B\[[0-9;]*m/g, '').replace(/\u001B\[[0-9;]*[a-zA-Z]/g, ''); }
                                    function cleanLine(str) {
                                        str = stripAnsi(str);
                                        if (/^[-=\s|]+$/.test(str.trim())) return null;
                                        if ((str.match(/-/g) || []).length > 4) return null;
                                        str = str.replace(/guilds\/guild_\d+\s*\\n\s*/g, '');
                                        str = str.replace(/guilds\/guild_\d+\n/g, '');
                                        str = str.replace(/\|\s*\|/g, '|');
                                        str = str.replace(/\s{3,}/g, '  ').trim();
                                        if (!str || /^[\s|]+$/.test(str)) return null;
                                        return str;
                                    }
                                    if (outputLines.length === 0) {
                                        sendServerMsg('[ADMIN]', 0, 220, 100, '\u2713 Done: /' + cmd);
                                    } else {
                                        outputLines.forEach(function (line) { var cleaned = cleanLine(line); if (cleaned) sendServerMsg('[ADMIN]', 0, 220, 100, cleaned); });
                                    }
                                }, 300);
                            } else {
                                sendServerMsg('[ADMIN]', 255, 80, 80, '\u2717 Unknown: /' + first);
                            }
                        } else {
                            sendServerMsg('[SERVER]', 255, 80, 80, '\u2717 You are not an admin!');
                        }
                    } catch (e) { console.log('Admin cmd error:', e); }
                });
                break;
            }

            // ✅ FIX: Guild chat /g - hapus semua HTTP per-client, pakai guildId dari playerTracker
            if (message.charAt(0) === '/' && (message.substr(0, 3).toLowerCase() === '/g ' || message.toLowerCase() === '/g')) {
                if (message.toLowerCase() === '/g') break;
                var guildMsg = message.substr(3).trim();
                if (!guildMsg) break;

                var selfSocket = this.socket;
                var selfTracker = selfSocket.playerTracker;
                var myGuildId = selfTracker ? selfTracker.guildId : null;

                // Kalau guildId belum ada di tracker, fetch dulu sekali
                var cleanName = wname;
                if (cleanName.indexOf('] ') !== -1) cleanName = cleanName.split('] ')[1] || cleanName;
                cleanName = cleanName.replace(/^[\x01\x02\x03\x04]/, '');

                var gs = selfTracker ? selfTracker.gameServer : null;
                if (!gs) break;

                function doGuildBroadcast(gId) {
                    if (!gId) return;
                    gs.getCachedRole(cleanName, function (rd) {
                        var glowPrefix = '';
                        if (rd.role === 'admin') glowPrefix = '\x01';
                        else if (rd.role === 'mod') glowPrefix = '\x02';

                        function sendGuildMsg(targetSocket) {
                            var senderName = glowPrefix + wname;
                            var msg = '\x03' + guildMsg;
                            var isSpec = selfSocket.playerTracker && selfSocket.playerTracker.spectate;
                            var nc = (!isSpec) && selfSocket.playerTracker && selfSocket.playerTracker.color;
                            var nr = nc ? nc.r : 180;
                            var ng = nc ? nc.g : 180;
                            var nb = nc ? nc.b : 180;
                            var buf = new ArrayBuffer(9 + 2 * senderName.length + 2 * msg.length);
                            var view = new DataView(buf);
                            view.setUint8(0, 99); view.setUint8(1, 0);
                            view.setUint8(2, nr); view.setUint8(3, ng); view.setUint8(4, nb);
                            var offset = 5;
                            for (var j = 0; j < senderName.length; j++) { view.setUint16(offset, senderName.charCodeAt(j), true); offset += 2; }
                            view.setUint16(offset, 0, true); offset += 2;
                            for (var j = 0; j < msg.length; j++) { view.setUint16(offset, msg.charCodeAt(j), true); offset += 2; }
                            view.setUint16(offset, 0, true);
                            try { targetSocket.send(buf); } catch (e) { }
                        }

                        // ✅ Cukup cek guildId dari playerTracker — tidak ada HTTP per-client lagi!
                        var allClients = gs.clients || [];
                        for (var ci = 0; ci < allClients.length; ci++) {
                            var targetTracker = allClients[ci].playerTracker;
                            if (targetTracker && targetTracker.guildId && targetTracker.guildId === gId) {
                                sendGuildMsg(allClients[ci]);
                            }
                        }
                    });
                }

                if (myGuildId) {
                    doGuildBroadcast(myGuildId);
                } else {
                    // Fetch sekali, simpan ke tracker, lalu broadcast
                    gs.getCachedGuildId(cleanName, function (gId) {
                        if (selfTracker) selfTracker.guildId = gId;
                        doGuildBroadcast(gId);
                    });
                }
                break;
            }

            // Spam check
            if (message == LastMsg) {
                ++SpamBlock;
                if (SpamBlock > 10) this.gameServer.banned.push(this.socket.remoteAddress);
                if (SpamBlock > 5) this.socket.close();
                if (SpamBlock <= 3) { } else { break; }
            }
            LastMsg = message;
            SpamBlock = 0;

            console.log("\u001B[36m" + wname + ": \u001B[0m" + message);

            var hour = date.getHours();
            hour = (hour < 10 ? "0" : "") + hour;
            var min = date.getMinutes();
            min = (min < 10 ? "0" : "") + min;
            hour += ":" + min;

            var chatSender = Object.create(this.socket.playerTracker);
            chatSender.name = wname;

            var self = this;
            var cleanNameForRole = wname;

            self.gameServer.chatLogStream.write('[' + hour + '] ' + wname + ': ' + message + '\n');
            if (cleanNameForRole.indexOf('] ') !== -1) cleanNameForRole = cleanNameForRole.split('] ')[1] || cleanNameForRole;
            cleanNameForRole = cleanNameForRole.replace(/^[\x01\x02\x03\x04]/, '');

            // ✅ FIX: role dari cache, bukan HTTP langsung
            self.gameServer.getCachedRole(cleanNameForRole, function (roleData) {
                var prefix = '';
                if (roleData.role === 'admin') prefix = '\x01';
                else if (roleData.role === 'mod') prefix = '\x02';
                chatSender.name = prefix + wname;

                // chatcolor tetap HTTP karena bisa berubah kapan saja
                self.gameServer.getCachedChatColor(cleanNameForRole, function (chatColor) {
                    var packet = new Packet.Chat(chatSender, message, chatColor);
                    for (var i = 0; i < self.gameServer.clients.length; i++) {
                        self.gameServer.clients[i].sendPacket(packet);
                    }
                });
            });
            break;

        default:
            break;
    }
};

PacketHandler.prototype.setNickname = function (newNick, skin) {
    var client = this.socket.playerTracker;
    var gameServer = this.gameServer;
    if (client.cells.length < 1) {
        var color = null;
        if (newNick.indexOf('|') !== -1) {
            var parts = newNick.split('|');
            var maybeColor = parts[0];
            if (maybeColor.charAt(0) === '#' && maybeColor.length === 7) {
                color = maybeColor;
                newNick = parts.slice(1).join('|');
            }
        }

        var cleanNickForRole = newNick;
        if (cleanNickForRole.indexOf('] ') !== -1) cleanNickForRole = cleanNickForRole.split('] ')[1] || cleanNickForRole;

        // ✅ FIX: pakai cache, bukan HTTP langsung
        gameServer.getCachedRole(cleanNickForRole, function (rd) {
            var finalNick = newNick;
            try {
                var roles = rd.roles || [rd.role];
                if (roles.includes('noname')) finalNick = '\x04' + newNick;
            } catch (e) { }

            if (skin) client.setName(skin + '\n' + finalNick);
            else client.setName(finalNick);

            if (color) {
                var r = parseInt(color.slice(1, 3), 16);
                var g = parseInt(color.slice(3, 5), 16);
                var b = parseInt(color.slice(5, 7), 16);
                client.color = { r: r, g: g, b: b };
            }

            // ✅ Simpan guildId ke playerTracker — guild chat tidak perlu HTTP per-player lagi
            gameServer.getCachedGuildId(cleanNickForRole, function (guildId) {
                client.guildId = guildId;
                gameServer.gameMode.onPlayerSpawn(gameServer, client);
                client.spectate = false;
            });
        });
    }
};