const toast = document.querySelector('.toast');
let toastTimer;

function showToast(message) {
  toast.textContent = message;
  toast.classList.add('visible');
  clearTimeout(toastTimer);
  toastTimer = setTimeout(() => toast.classList.remove('visible'), 4300);
}

document.querySelectorAll('[data-message]').forEach((button) => {
  button.addEventListener('click', () => showToast(button.dataset.message));
});

document.querySelectorAll('[data-scroll]').forEach((button) => {
  button.addEventListener('click', () => document.getElementById(button.dataset.scroll).scrollIntoView({ behavior: 'smooth' }));
});

document.querySelectorAll('.bottom-nav a').forEach((item) => {
  item.addEventListener('click', () => {
    document.querySelectorAll('.bottom-nav .nav-item').forEach((link) => link.classList.remove('active'));
    item.classList.add('active');
  });
});
