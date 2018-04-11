$(document).ready(() => {
  setTimeout(() => {
    $('.banner-wrapper .in-flight').removeClass('in-flight');
  }, 100);

  $(window).scroll(() => {
    const wScroll = $(window).scrollTop();
    const viewportHeight = window.innerHeight;
    
    $('section .in-flight').each((index, element) => {
      var sectionOffset = $(element).closest('section').offset().top;
      if (wScroll > (sectionOffset - (viewportHeight * 0.9))) {
        $(element).removeClass('in-flight');
      }
    });
  });
});