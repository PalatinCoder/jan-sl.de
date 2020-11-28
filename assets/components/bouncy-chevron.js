document.querySelectorAll('.icon.is-clickable').forEach(el => {
    el.addEventListener('click', function(e) { // no arrow function here because of the binding context of 'this'!
        e.preventDefault();
        document.querySelector(this.getAttribute('href')).scrollIntoView({
            behavior: 'smooth'
        });
    });
});
