const SteamUser = require("steam-user");
const SteamTotp = require("steam-totp");
require("dotenv").config();

const user = new SteamUser();

const status = 7; // 0 = offline, 1 = online, 2 = busy, 3 = away, 4 = snooze, 5 = looking to trade, 6 = looking to play 7 = invisible

const games = [2399830];

const logOnOptions = {
  accountName: process.env.username,
  password: process.env.password,
  twoFactorCode: SteamTotp.generateAuthCode(process.env.shared),
};

user.logOn(logOnOptions);

user.on("loggedOn", () => {
  console.log(
    "User:" +
      logOnOptions.accountName +
      " ID:" +
      user.steamID +
      " - Successfully logged into Steam."
  );
  user.setPersona(status);
  user.gamesPlayed(games);
});
