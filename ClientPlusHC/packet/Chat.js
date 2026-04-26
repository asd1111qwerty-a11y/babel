function Chat(sender, message, chatColor) {
    this.sender = sender;
    this.message = message;
    this.chatColor = chatColor || null; // ✅ tambah parameter
}

module.exports = Chat;

Chat.prototype.build = function () {
    var nick = this.sender.getName();
    if (!nick) {
        if (this.sender.cells.length > 0) {
            nick = 'An unnamed cell'
        } else {
            nick = 'Spectator'
        }
    }

    // ✅ +4 byte untuk [hasMsgColor][r][g][b]
    var buf = new ArrayBuffer(9 + 2*nick.length + 2*this.message.length + 4);
    var view = new DataView(buf);
    var color = {'r':155,'g':155,'b':155};
    if (this.sender.cells.length > 0) {
        color = this.sender.cells[0].getColor();
    }
    view.setUint8(0, 99);
    view.setUint8(1, 0);
    view.setUint8(2, color.r);
    view.setUint8(3, color.g);
    view.setUint8(4, color.b);
    var offset = 5;
    for (var j = 0; j < nick.length; j++) {
        view.setUint16(offset, nick.charCodeAt(j), true);
        offset += 2;
    }
    view.setUint16(offset, 0, true);
    offset += 2;
    for (var j = 0; j < this.message.length; j++) {
        view.setUint16(offset, this.message.charCodeAt(j), true);
        offset += 2;
    }
    view.setUint16(offset, 0, true);
    offset += 2;

    // ✅ Append custom msg color
    if (this.chatColor && this.chatColor.charAt(0) === '#' && this.chatColor.length === 7) {
        view.setUint8(offset, 1); // has custom color
        view.setUint8(offset+1, parseInt(this.chatColor.slice(1,3), 16));
        view.setUint8(offset+2, parseInt(this.chatColor.slice(3,5), 16));
        view.setUint8(offset+3, parseInt(this.chatColor.slice(5,7), 16));
    } else {
        view.setUint8(offset, 0); // no custom color
        view.setUint8(offset+1, 0);
        view.setUint8(offset+2, 0);
        view.setUint8(offset+3, 0);
    }

    return buf;
};