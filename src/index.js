const path = require("path");
const SteamUser = require("steam-user");
const SteamTotp = require("steam-totp");
require("dotenv").config({ path: path.resolve(__dirname, "../.env") });
const { games, games2 } = require("./data/gamesIds.js");

const accounts = [
  {
    username: process.env.username_1,
    password: process.env.password_1,
    shared: process.env.shared_1,
    games: games,
  },
  {
    username: process.env.username_2,
    password: process.env.password_2,
    shared: process.env.shared_2,
    games: games2,
  },
];

const status = 1; // 0 = offline, 1 = online, 2 = busy, 3 = away, 4 = snooze, 5 = looking to trade, 6 = looking to play, 7 = invisible

function getRandomGames(gameList, count) {
  let randomGames = [];
  while (randomGames.length < count) {
    const randomGame = gameList[Math.floor(Math.random() * gameList.length)];
    if (!randomGames.includes(randomGame)) {
      randomGames.push(randomGame);
    }
  }
  return randomGames;
}

function printDuplicatedGameIds(gameList) {
  const gameIds = gameList.map((game) => game.id);
  const duplicates = gameIds.filter(
    (id, index) => gameIds.indexOf(id) !== index
  );
  const uniqueDuplicates = [...new Set(duplicates)];
  if (uniqueDuplicates.length > 0) {
    console.log(`Duplicated game IDs found: ${uniqueDuplicates.join(", ")}`);
  } else {
    console.log("No duplicated game IDs found.");
  }
}

function updateGames(user, games) {
  printDuplicatedGameIds(games); // Check for duplicates before updating

  const gamesToPlay = games.length > 32 ? getRandomGames(games, 32) : games;
  const gameIds = gamesToPlay.map((game) => game.id);
  const gameNames = gamesToPlay.map((game) => game.name);
  user.gamesPlayed(gameIds);

  console.log(
    `Currently farming ${gamesToPlay.length} of ${games.length} games:`,
    gameNames
  );
}

accounts.forEach((account) => {
  const user = new SteamUser();
  const logOnOptions = {
    accountName: account.username,
    password: account.password,
    twoFactorCode: SteamTotp.generateAuthCode(account.shared),
  };

  user.logOn(logOnOptions);

  user.on("loggedOn", () => {
    console.log(
      `User: ${logOnOptions.accountName} ID: ${user.steamID} - Successfully logged into Steam.`
    );
    user.setPersona(status);

    // Initial game update
    updateGames(user, account.games);

    // Update games every hour
    setInterval(() => {
      updateGames(user, account.games);
    }, 60 * 60 * 1000); // 1 hour in milliseconds
  });

  user.on("error", (err) => {
    console.error(`Error for account ${account.username}: ${err}`);
  });

  user.on("ownedGames", (ownedApps) => {
    account.games = account.games.filter((game) => ownedApps.includes(game.id));
    updateGames(user, account.games);
  });
});
