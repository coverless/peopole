import { Component } from '@angular/core';
import { AngularFireDatabase, FirebaseListObservable, FirebaseObjectObservable } from 'angularfire2/database';
import 'rxjs/add/operator/take';

class listPerson {
  key: string
  name: string;
  results: number;
  wikipedia: string;
}

@Component({
  selector: 'app-root',
  templateUrl: `./app.component.html`
})
export class AppComponent {

  top50: FirebaseListObservable<any>;
  peopleInformation: FirebaseListObservable<any>;
  list:listPerson[] = [];
  infoList:listPerson[] = [];

  constructor(db: AngularFireDatabase) {

    // pull top-50-today from DB into Firebase list
    this.top50 = db.list('/top-50-today/2017-09-17', {
      query: {
        orderByValue: true,
        preserveSnapshot: true
      }
    });

    // pull people-information from DB into Firebase list
    this.peopleInformation = db.list('/people-information', {
      query: {
        orderByValue: true,
        preserveSnapshot: true
      }
    });

    // manipulate Firebase top-50-today into sorted TypeScript list
    this.top50.subscribe(people => {
      let count = 24;
      people.forEach(person => {
        this.list[count] = new listPerson;
        this.list[count].key = person.$key;
        this.list[count].results = person.$value;
        count--;
      })
    })

    // manipulate Firebase people-information into sorted TypeScript list
    this.peopleInformation.subscribe(people => {
      people.forEach(person => {
        for(var count = 0; count < 25; count++) {
          if(this.list[count].key == person.$key) {
            this.list[count].name = person.name;
            this.list[count].wikipedia = person.wikipedia;
          }
        }
      })
    })
    
  }

}
