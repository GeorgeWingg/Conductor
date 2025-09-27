const moves = ['rock','paper','scissors'];
const rules = {
  rock: {beats: 'scissors'},
  paper: {beats: 'rock'},
  scissors: {beats: 'paper'}
};

let ps = 0, cs = 0;
const psEl = document.getElementById('ps');
const csEl = document.getElementById('cs');
const result = document.getElementById('result');

function cpu() {
  return moves[Math.floor(Math.random()*moves.length)];
}

function play(player) {
  const c = cpu();
  if (player === c) {
    result.textContent = `Both chose ${player}. Draw.`;
    result.className = 'result draw';
  } else if (rules[player].beats === c) {
    ps++; psEl.textContent = ps;
    result.textContent = `${player} beats ${c}. You win!`;
    result.className = 'result win';
  } else {
    cs++; csEl.textContent = cs;
    result.textContent = `${c} beats ${player}. You lose.`;
    result.className = 'result lose';
  }
}

document.querySelectorAll('.choice').forEach(btn => {
  btn.addEventListener('click', () => play(btn.dataset.move));
});