Feature: Team Member live board updater
  As a team member
  I want to have realtime updates on my boards
  So that I can collaborate with others during planning

  Background:
    Given the ecookbook project has the backlogs plugin enabled
      And sharing is enabled
      And I have defined the following projects:
        | name   |
        | p1     |
        | p1s1   |
        | p1s2   |

      And the p1 project has the backlogs plugin enabled
      And the p1s1 project has the backlogs plugin enabled
      And the p1s1 project is subproject of the p1 project
      And the p1s2 project has the backlogs plugin enabled
      And the p1s2 project is subproject of the p1 project
      And no versions or issues exist
      And I am a team member of the project

      And I have defined the following sprints:
        | name       | sprint_start_date | effective_date | sharing     | project_id    |
        | Sprint0    | 2010-01-01        | 2010-01-31     | hierarchy   | p1            |
        | Sprint1    | 2010-01-01        | 2010-01-31     | hierarchy   | p1s1          |
        | Sprint2    | 2010-01-01        | 2010-01-31     | hierarchy   | p1s2          |
        | Sprint3    | 2010-01-01        | 2010-01-31     | none        | p1s2          |

      And the current time is 2012-11-20 08:00:00

      And I have defined the following stories in the product backlog:
        | subject | project_id    |
        | Sb1     | p1     |
        | Sb2     | p1s1   |
        | Sb3     | p1s2   |
      And I have defined the following stories in the following sprints:
        | subject | sprint     | project_id |
        | Sp1s1   | Sprint0    | p1   |
        | Sp1s2   | Sprint0    | p1   |
        | Sp1s3   | Sprint1    | p1   |
        | Sp2s1   | Sprint1    | p1s1 |
        | Sp2s2   | Sprint2    | p1s2 |
        | Sp2s3   | Sprint3    | p1s2  |

  Scenario: Fetch the updated stories from several projects without sharing
    Given sharing is not enabled
    Given I have selected the p1 project
     When the browser fetches stories updated since 1 week ago
     Then Story "Sb1" should be updated
     Then Story "Sp1s1" should be updated
     Then Story "Sp1s2" should be updated
     Then Story "Sp1s3" should not be updated
     Then Story "Sb2" should not be updated
     Then the server should return 3 updated stories
    Given I have selected the p1s1 project
     When the browser fetches stories updated since 1 week ago
     Then the server should return 2 updated stories
     Then Story "Sb2" should be updated
     Then Story "Sb1" should not be updated
     Then Story "Sp2s1" should be updated
    Given I have selected the p1s2 project
     When the browser fetches stories updated since 1 week ago
     Then the server should return 3 updated stories
     Then Story "Sb3" should be updated
     Then Story "Sp2s2" should be updated
     Then Story "Sp2s3" should be updated
     Then Story "Sb1" should not be updated

  Scenario: Fetch the updated stories from several projects with sharing
    Given sharing is enabled
    Given I have selected the p1 project
     When the browser fetches stories updated since 1 week ago
     Then Story "Sb1" should be updated
     Then Story "Sb2" should be updated
     Then Story "Sb3" should be updated
     Then Story "Sp1s1" should be updated
     Then Story "Sp1s2" should be updated
     Then Story "Sp1s3" should be updated
     Then Story "Sp2s1" should be updated
     Then Story "Sp2s2" should be updated
     Then Story "Sp2s3" should not be updated
     Then the server should return 8 updated stories
    Given I have selected the p1s1 project
     When the browser fetches stories updated since 1 week ago
     Then Story "Sb2" should be updated
     Then Story "Sp1s1" should be updated
     Then Story "Sp1s2" should be updated
     Then Story "Sp1s3" should be updated
     Then Story "Sp2s1" should be updated
     Then Story "Sp2s2" should not be updated
     Then Story "Sp2s3" should not be updated
     Then the server should return 5 updated stories
    Given I have selected the p1s2 project
     When the browser fetches stories updated since 1 week ago
     Then Story "Sb3" should be updated
     Then Story "Sp1s1" should be updated
     Then Story "Sp1s2" should be updated
     Then Story "Sp2s2" should be updated
     Then Story "Sp2s3" should be updated
     Then Story "Sp1s3" should not be updated
     Then Story "Sb2" should not be updated
     Then Story "Sb1" should not be updated
     Then the server should return 5 updated stories

  Scenario: Get the last updated stories date when viewing master backlog
    Given sharing is enabled
      And the current time is 2012-11-20 10:00:00
      And I have defined the following stories in the product backlog:
        | subject | project_id    |
        | Sb1     | p1     |
      And I have selected the p1 project
      And I am viewing the master backlog
     Then The last_update information should be near November 20, 2012 10:00

    Given the current time is 2012-11-20 12:00:00
      And I have defined the following stories in the following sprints:
        | subject | sprint     | project_id |
        | lorem   | Sprint2    | p1s2 |
      And I have selected the p1 project
      And I am viewing the master backlog
     Then The last_update information should be near November 20, 2012 12:00

#FIXME taskboard checks
