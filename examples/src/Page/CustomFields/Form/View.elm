module Page.CustomFields.Form.View exposing
    ( Model
    , State(..)
    , ViewConfig
    , asHtml
    , idle
    )

import Form.Base as Base
import Form.Error as Error exposing (Error)
import Form.View
import Html exposing (Html)
import Html.Attributes as Attributes
import Html.Events as Events
import Page.CustomFields.Form as Form exposing (Form)


type alias Model values =
    { values : values
    , state : State
    , errorTracking : ErrorTracking
    }


type State
    = Idle
    | Loading
    | Error String


type ErrorTracking
    = ErrorTracking { showAllErrors : Bool }


idle : values -> Model values
idle values =
    { values = values
    , state = Idle
    , errorTracking =
        ErrorTracking
            { showAllErrors = False
            }
    }


type alias ViewConfig values msg =
    { onChange : Model values -> msg
    , action : String
    , loading : String
    }


asHtml : ViewConfig values msg -> Form values msg msg -> Model values -> Html msg
asHtml { onChange, action, loading } form model =
    let
        { fields, result } =
            Form.fill form model.values

        errorTracking =
            (\(ErrorTracking e) -> e) model.errorTracking

        onSubmit =
            case result of
                Ok msg ->
                    if model.state == Loading then
                        Nothing

                    else
                        Just msg

                Err _ ->
                    if errorTracking.showAllErrors then
                        Nothing

                    else
                        Just
                            (onChange
                                { model
                                    | errorTracking =
                                        ErrorTracking { errorTracking | showAllErrors = True }
                                }
                            )

        fieldToElement =
            field
                { disabled = model.state == Loading
                , showError = errorTracking.showAllErrors
                }

        onSubmitEvent =
            onSubmit
                |> Maybe.map (Events.onSubmit >> List.singleton)
                |> Maybe.withDefault []
    in
    Html.form (Attributes.class "elm-form" :: onSubmitEvent)
        (List.concat
            [ List.map fieldToElement fields
            , [ case model.state of
                    Error error ->
                        errorMessage error

                    _ ->
                        Html.text ""
              , Html.button
                    [ Attributes.type_ "submit"
                    , Attributes.disabled (onSubmit == Nothing)
                    ]
                    [ if model.state == Loading then
                        Html.text loading

                      else
                        Html.text action
                    ]
              ]
            ]
        )


field : { disabled : Bool, showError : Bool } -> Base.FilledField (Form.Field values msg) -> Html msg
field { disabled, showError } field_ =
    case field_.state of
        Form.Email { onChange, state, value, attributes } ->
            emailField
                { onChange = onChange
                , onBlur = Nothing
                , value = value
                , disabled = disabled || field_.isDisabled
                , error = field_.error
                , showError = state == Form.EmailValidated
                , attributes = attributes
                }
                state


emailField : Form.View.TextFieldConfig msg -> Form.EmailState -> Html msg
emailField { onChange, disabled, value, error, showError, attributes } state =
    Html.div
        [ Attributes.classList
            [ ( "elm-form-field", True )
            , ( "elm-form-field-error", showError && error /= Nothing )
            ]
        ]
        [ fieldLabel attributes.label
        , Html.div [ Attributes.class "custom-email-input" ]
            [ Html.input
                [ Events.onInput onChange
                , Attributes.disabled disabled
                , Attributes.value value
                , Attributes.placeholder attributes.placeholder
                , Attributes.type_ "email"
                ]
                []
            , case state of
                Form.EmailLoading ->
                    Html.i [ Attributes.class "fas fa-spinner fa-pulse" ] []

                Form.EmailValidated ->
                    if error == Nothing then
                        Html.i [ Attributes.class "fas fa-check" ] []

                    else
                        Html.i [ Attributes.class "fas fa-times" ] []

                Form.EmailNotValidated ->
                    Html.text ""
            ]
        , maybeErrorMessage showError error
        ]


fieldLabel : String -> Html msg
fieldLabel label =
    Html.label [] [ Html.text label ]


maybeErrorMessage : Bool -> Maybe Error -> Html msg
maybeErrorMessage showError maybeError =
    if showError then
        maybeError
            |> Maybe.map errorToString
            |> Maybe.map errorMessage
            |> Maybe.withDefault (Html.text "")

    else
        Html.text ""


errorMessage : String -> Html msg
errorMessage =
    Html.text >> List.singleton >> Html.div [ Attributes.class "elm-form-error" ]


errorToString : Error -> String
errorToString error =
    case error of
        Error.RequiredFieldIsEmpty ->
            "(*)"

        Error.ValidationFailed validationError ->
            validationError

        Error.External externalError ->
            externalError
