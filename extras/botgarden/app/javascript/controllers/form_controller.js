// TODO try to use stimulus to more gracefully handle blank search result form input

import { Controller } from "@hotwired/stimulus"

  export default class extends Controller {

    static targets = ["csvField"]


    submitForm(event) {
      console.log("hello");
      // event.preventDefault();
      // const csvFields = this.csvFieldTargets
      // csvFields.forEach(field => {
      //   console.log(field);
      // })
      // console.log("Form submitted using Stimulus!");
      // // Your JavaScript logic here

    }
  }