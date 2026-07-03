document.querySelectorAll(".carousel").forEach(function (carousel) {
    var slides = carousel.querySelectorAll(".carousel-slide");
    var dots = carousel.querySelectorAll(".carousel-dot");
    var current = 0;

    function goTo(index) {
        slides[current].classList.remove("active");
        slides[current].setAttribute("aria-hidden", "true");
        dots[current].classList.remove("active");
        current = (index + slides.length) % slides.length;
        slides[current].classList.add("active");
        slides[current].setAttribute("aria-hidden", "false");
        dots[current].classList.add("active");
    }

    carousel.querySelector(".carousel-prev").addEventListener("click", function () {
        goTo(current - 1);
    });

    carousel.querySelector(".carousel-next").addEventListener("click", function () {
        goTo(current + 1);
    });

    dots.forEach(function (dot, i) {
        dot.addEventListener("click", function () {
            goTo(i);
        });
    });

    carousel.addEventListener("keydown", function (e) {
        if (e.key === "ArrowLeft") goTo(current - 1);
        if (e.key === "ArrowRight") goTo(current + 1);
    });
});
