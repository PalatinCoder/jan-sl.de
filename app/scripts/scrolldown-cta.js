$(() => {
  $('.banner-wrapper i').click(() => {
    $('html, body').animate({
      scrollTop: $('#me').offset().top
    }, 'slow');
  });
});